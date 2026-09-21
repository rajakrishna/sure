require "application_system_test_case"

class AiProposalsTest < ApplicationSystemTestCase
  include EntriesTestHelper

  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
    @account = @family.accounts.create!(name: "Proposal UI", balance: 50, currency: "USD", accountable: Depository.new)
    @category = @family.categories.create!(name: "Proposal Coffee UI")
    @transaction = create_transaction(account: @account, name: "Blue Bottle UI").transaction
    AiProposal.propose_categorize!(
      family: @family,
      transaction: @transaction,
      category_id: @category.id,
      source: "auto_categorize",
      user: @user
    )
    @proposal = @family.ai_proposals.pending.sole
  end

  test "accepting one proposal from the card writes the category" do
    visit ai_proposals_url
    assert_text @proposal.summary

    within("##{dom_id(@proposal)}") do
      find("button[data-testid=proposal-accept]").click
    end

    assert_no_selector "button[data-testid=proposal-accept]", wait: 10
    assert_equal @category, @transaction.reload.category
    assert_equal "approved", @proposal.reload.status
  end

  test "bulk accept writes selected proposals" do
    visit ai_proposals_url
    assert_text @proposal.summary

    find("input[name='proposal_ids[]'][value='#{@proposal.id}']", visible: :all).set(true)
    click_button I18n.t("ai_proposals.index.bulk_approve")

    assert_no_selector "button[data-testid=proposal-accept]", wait: 10
    assert_equal @category, @transaction.reload.category
    assert_equal "approved", @proposal.reload.status
  end
end
