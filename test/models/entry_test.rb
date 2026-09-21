require "test_helper"

class EntryTest < ActiveSupport::TestCase
  include EntriesTestHelper

  test "chronological ordering uses id as final tie breaker" do
    account = accounts(:depository)
    timestamp = Time.zone.parse("2026-05-05 12:00:00")

    entries = 3.times.map do |index|
      create_transaction(
        account: account,
        name: "Same timestamp transaction #{index}",
        date: Date.new(2026, 5, 5),
        created_at: timestamp,
        updated_at: timestamp
      )
    end

    entry_ids = entries.map(&:id)

    assert_equal entry_ids.sort, Entry.where(id: entry_ids).chronological.pluck(:id)
    assert_equal entry_ids.sort.reverse, Entry.where(id: entry_ids).reverse_chronological.pluck(:id)
  end

  test "accessible_uncategorized_count is not inflated by multiple account shares" do
    user = users(:family_admin)
    account = accounts(:depository)
    AccountShare.create!(account: account, user: family_guest, permission: "read_only", include_in_finances: true)
    create_transaction(account: account, name: "Count-stable uncategorized")

    canonical = Entry.accessible_uncategorized_count(user)
    joined = user.family.entries
      .joins(:account)
      .merge(Account.accessible_by(user))
      .uncategorized_transactions
      .count

    assert_operator canonical, :>=, 1
    assert_equal canonical, user.family.entries
      .where(account_id: user.accessible_accounts.select(:id))
      .uncategorized_transactions
      .distinct
      .count("entries.id")
    assert_operator joined, :>=, canonical
  end

  test "accessible_uncategorized_count is zero when nothing is uncategorized" do
    user = users(:family_admin)
    category = categories(:food_and_drink)
    user.family.entries.uncategorized_transactions.find_each do |entry|
      entry.entryable.update!(category: category)
    end

    assert_equal 0, Entry.accessible_uncategorized_count(user)
  end

  test "bulk_update! touches the assigned category's last_used_at" do
    entry = create_transaction(account: accounts(:depository))
    category = categories(:income)
    assert_nil category.last_used_at

    Entry.where(id: entry.id).bulk_update!({ category_id: category.id })

    assert_not_nil category.reload.last_used_at
  end
end
