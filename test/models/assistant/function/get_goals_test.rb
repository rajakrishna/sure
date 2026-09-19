require "test_helper"

class Assistant::Function::GetGoalsTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @function = Assistant::Function::GetGoals.new(@user)
  end

  test "lists active goals with progress" do
    result = @function.call

    names = result[:goals].map { |goal| goal[:name] }
    assert_includes names, goals(:vacation_italy).name
    assert result[:goals].all? { |goal| goal[:target_amount].present? }
    assert result[:goals].all? { |goal| goal[:current_balance].present? }
  end

  test "omits archived goals unless requested" do
    archived = goals(:vacation_italy)
    archived.archive!

    hidden = @function.call
    assert_not_includes hidden[:goals].map { |goal| goal[:id] }, archived.id

    shown = @function.call("include_archived" => true)
    assert_includes shown[:goals].map { |goal| goal[:id] }, archived.id
  end
end
