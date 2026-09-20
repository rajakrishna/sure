# Summary data for the Plan hub tabs (bills, debt, forecast).
# Budget and goals keep their existing controller-loaded objects; this PORO
# only gathers the extra planning snapshots so the hub controller stays thin.
class PlanHub
  TABS = %w[budget goals bills debt forecast cash_flow].freeze
  BUDGET_MODES = %w[categories spending_plan].freeze
  DEBT_ACCOUNT_TYPES = %w[CreditCard Loan].freeze
  FORECAST_HORIZON_DAYS = 30
  NEXT_UP_LIMIT = 4

  def self.tab_for(tab)
    candidate = tab.to_s
    TABS.include?(candidate) ? candidate : "budget"
  end

  def self.budget_mode_for(mode)
    candidate = mode.to_s
    BUDGET_MODES.include?(candidate) ? candidate : "categories"
  end

  def initialize(family:, user:)
    @family = family
    @user = user
  end

  def recurring_disabled?
    family.recurring_transactions_disabled?
  end

  def overdue_count
    overdue_occurrences.size
  end

  def remaining_this_month
    total_of(owed_this_month) { |occurrence| occurrence.remaining_amount_money }
  end

  def overdue_total
    total_of(overdue_occurrences) { |occurrence| occurrence.remaining_amount_money }
  end

  def due_next_seven
    upcoming = owed_this_month.select { |occurrence| occurrence.effective_due_on <= Date.current + 7 }
    total_of(upcoming) { |occurrence| occurrence.remaining_amount_money }
  end

  def next_up
    open_occurrences
      .reject { |occurrence| occurrence.effective_due_on < Date.current }
      .sort_by(&:effective_due_on)
      .first(NEXT_UP_LIMIT)
  end

  def forecast_obligations
    open_occurrences
      .select { |occurrence| occurrence.effective_due_on <= Date.current + FORECAST_HORIZON_DAYS }
  end

  def forecast_bills_total
    total_of(forecast_obligations) { |occurrence| occurrence.remaining_amount_money }
  end

  def debt_accounts
    @debt_accounts ||= user.accessible_accounts
                           .visible
                           .where(accountable_type: DEBT_ACCOUNT_TYPES)
                           .includes(:accountable)
                           .order(:name)
                           .to_a
  end

  def debt_total
    sum_accounts(debt_accounts)
  end

  def cash_accounts
    @cash_accounts ||= user.accessible_accounts
                           .visible
                           .where(accountable_type: "Depository")
                           .to_a
  end

  def cash_on_hand
    sum_accounts(cash_accounts)
  end

  def forecast_remainder
    cash_on_hand - forecast_bills_total
  end

  private
    attr_reader :family, :user

    def payable_series_ids
      family.recurring_transactions.payable.accessible_by(user).select(:id)
    end

    def open_occurrences
      return [] if recurring_disabled?

      @open_occurrences ||= begin
        rows = family.recurring_occurrences
                     .where(recurring_transaction_id: payable_series_ids)
                     .open_status
                     .where("due_on <= ?", Date.current + FORECAST_HORIZON_DAYS)
                     .includes(recurring_transaction: :merchant)
                     .to_a
        preload_allocation_sums(rows)
        rows
      end
    end

    def overdue_occurrences
      open_occurrences.select(&:overdue?)
    end

    def owed_this_month
      month_end = Date.current.end_of_month
      open_occurrences.select do |occurrence|
        occurrence.overdue? || occurrence.effective_due_on <= month_end
      end
    end

    def preload_allocation_sums(occurrences)
      return if occurrences.empty?

      sums = RecurringAllocation.confirmed
                                .where(recurring_occurrence_id: occurrences.map(&:id))
                                .group(:recurring_occurrence_id)
                                .sum(:allocated_amount)

      occurrences.each do |occurrence|
        occurrence.cached_confirmed_allocated = sums.fetch(occurrence.id, 0)
      end
    end

    def total_of(occurrences)
      occurrences.reduce(Money.new(0, family.currency)) do |sum, occurrence|
        sum + yield(occurrence).exchange_to(family.currency)
      rescue Money::ConversionError
        sum
      end
    end

    def sum_accounts(accounts)
      accounts.reduce(Money.new(0, family.currency)) do |sum, account|
        sum + account.balance_money.exchange_to(family.currency)
      rescue Money::ConversionError
        sum
      end
    end
end
