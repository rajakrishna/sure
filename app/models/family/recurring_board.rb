class Family::RecurringBoard
  Item = Data.define(:name, :due_on, :amount, :status, :href, :recurring_transaction_id)

  def initialize(family, user:, month: Date.current.beginning_of_month)
    @family = family
    @user = user
    @month = month.beginning_of_month
  end

  def items
    occurrences.map do |occurrence|
      series = occurrence.recurring_transaction
      Item.new(
        name: series.display_name,
        due_on: occurrence.effective_due_on,
        amount: occurrence.remaining_amount_money,
        status: occurrence.status,
        href: Rails.application.routes.url_helpers.bill_path(series),
        recurring_transaction_id: series.id
      )
    end
  end

  def month
    @month
  end

  private
    attr_reader :family, :user

    def occurrences
      family.recurring_occurrences
        .joins(:recurring_transaction)
        .where(recurring_transactions: { status: :active })
        .where(due_on: @month..@month.end_of_month)
        .includes(recurring_transaction: :merchant)
        .order(:due_on)
    end
end
