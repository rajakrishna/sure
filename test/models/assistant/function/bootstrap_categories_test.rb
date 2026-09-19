require "test_helper"

class Assistant::Function::BootstrapCategoriesTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::BootstrapCategories.new(@user)
  end

  test "to_definition returns correct name" do
    definition = @fn.to_definition

    assert_equal "bootstrap_categories", definition[:name]
    assert_not_empty definition[:description]
    assert definition[:strict]
  end

  test "creates missing default categories" do
    existing_names = @family.categories.pluck(:name)

    result = nil
    assert_difference "@family.categories.count", 20 do
      result = @fn.call
    end

    assert result[:success]
    assert_equal 20, result[:created_count]
    assert_equal 20, result[:created].size
    created_names = result[:created].map { |category| category[:name] }
    existing_names.each { |name| assert_not_includes created_names, name }
  end

  test "is idempotent when defaults already exist" do
    @family.categories.bootstrap!

    result = nil
    assert_no_difference "@family.categories.count" do
      result = @fn.call
    end

    assert result[:success]
    assert_equal 0, result[:created_count]
    assert_empty result[:created]
    assert_match(/already present/, result[:message])
  end

  test "does not create categories on another family" do
    other_user = users(:new_email)
    other_fn = Assistant::Function::BootstrapCategories.new(other_user)

    other_fn.call

    assert other_user.family.categories.exists?
    assert_empty @family.categories.where(id: other_user.family.categories.select(:id))
  end
end
