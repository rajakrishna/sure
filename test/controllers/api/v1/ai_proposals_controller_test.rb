require "test_helper"

class Api::V1::AiProposalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    key = ApiKey.generate_secure_key
    @api_key = ApiKey.create!(user: @user, name: "Proposal test", key: key, scopes: [ "draft_write" ], source: "web")
    @read_key = ApiKey.create!(
      user: @user,
      name: "Proposal read",
      key: ApiKey.generate_secure_key,
      scopes: [ "read" ],
      source: "web"
    )
  end

  test "lists pending proposals" do
    AiProposal.propose_budget_adjust!(family: @user.family, user: @user, arguments: { "budgeted_spending" => 100 })

    get api_v1_ai_proposals_url, headers: api_headers(@read_key)

    assert_response :success
    assert_equal 1, response.parsed_body.fetch("ai_proposals").size
  end

  test "draft_write create_rule_draft does not write a rule" do
    category = @user.family.categories.first

    assert_no_difference "Rule.count" do
      post api_v1_ai_proposals_url, params: {
        function_name: "create_rule_draft",
        arguments: { match_value: "STARBUCKS", category_id: category.id }
      }, headers: api_headers(@api_key), as: :json
    end

    assert_response :created
    assert response.parsed_body["pending_approval"]
  end

  test "read key cannot create drafts" do
    post api_v1_ai_proposals_url, params: {
      function_name: "create_rule_draft",
      arguments: { match_value: "X", category_id: @user.family.categories.first.id }
    }, headers: api_headers(@read_key), as: :json

    assert_response :forbidden
  end

  test "dismiss marks a pending proposal dismissed" do
    proposal = AiProposal.propose_budget_adjust!(
      family: @user.family,
      user: @user,
      arguments: { "budgeted_spending" => 1234 }
    )

    post dismiss_api_v1_ai_proposal_url(proposal), headers: api_headers(@api_key), as: :json

    assert_response :success
    assert_equal "dismissed", proposal.reload.status
  end
end
