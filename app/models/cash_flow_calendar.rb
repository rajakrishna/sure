class CashFlowCalendar
  Event = Data.define(:name, :amount, :kind, :href, :due_on)
  Day = Data.define(:date, :in_month, :events, :inflow, :outflow, :net, :running_balance)

  WEEK_START = 0
  MAX_EVENTS_PER_DAY = 4

  def initialize(family:, user:, month:)
    @family = family
    @user = user
    @month_start = month.beginning_of_month
  end

  def month
    month_start
  end

  def month_end
    month_start.end_of_month
  end

  def grid_start
    month_start.beginning_of_week(:sunday)
  end

  def grid_end
    month_end.end_of_week(:sunday)
  end

  def previous_month
    month_start - 1.month
  end

  def next_month
    month_start + 1.month
  end

  def days
    @days ||= build_days
  end

  def month_inflow
    sum_money(days.select(&:in_month), :inflow)
  end

  def month_outflow
    sum_money(days.select(&:in_month), :outflow)
  end

  def month_net
    month_inflow - month_outflow
  end

  def ending_balance
    days.reverse.find { |day| day.in_month && day.running_balance }&.running_balance
  end

  def agenda_days
    days.select { |day| day.in_month && day.events.any? }
  end

  private
    attr_reader :family, :user, :month_start

    def currency
      family.currency
    end

    def zero
      Money.new(0, currency)
    end

    def cash_on_hand
      @cash_on_hand ||= user.accessible_accounts
                            .visible
                            .where(accountable_type: "Depository")
                            .reduce(zero) do |sum, account|
        sum + account.balance_money.exchange_to(currency)
      rescue Money::ConversionError
        sum
      end
    end

    def events_by_day
      @events_by_day ||= occurrences.each_with_object(Hash.new { |h, k| h[k] = [] }) do |occurrence, acc|
        date = occurrence.effective_due_on
        series = occurrence.recurring_transaction
        inflow = series.typed_income? || series.amount.negative?
        amount = occurrence.remaining_amount_money.exchange_to(currency)
        acc[date] << Event.new(
          name: series.display_name,
          amount: inflow ? amount : amount * -1,
          kind: inflow ? "income" : "bill",
          href: Rails.application.routes.url_helpers.bill_path(series),
          due_on: date
        )
      rescue Money::ConversionError
        next
      end
    end

    def occurrences
      return [] if family.recurring_transactions_disabled?

      rows = family.recurring_occurrences
                   .where(recurring_transaction_id: series_ids)
                   .open_status
                   .where(due_on: grid_start..grid_end)
                   .includes(recurring_transaction: :merchant)
                   .to_a
      preload_allocation_sums(rows)
      rows
    end

    def series_ids
      family.recurring_transactions
            .accessible_by(user)
            .active
            .where.not(bill_type: "transfer")
            .select(:id)
    end

    def preload_allocation_sums(rows)
      return if rows.empty?

      sums = RecurringAllocation.confirmed
                                .where(recurring_occurrence_id: rows.map(&:id))
                                .group(:recurring_occurrence_id)
                                .sum(:allocated_amount)

      rows.each do |occurrence|
        occurrence.cached_confirmed_allocated = sums.fetch(occurrence.id, 0)
      end
    end

    def build_days
      running = nil
      today = Date.current

      (grid_start..grid_end).map do |date|
        events = events_by_day[date] || []
        inflow = events.select { |event| event.kind == "income" }.reduce(zero) { |sum, event| sum + event.amount.abs }
        outflow = events.select { |event| event.kind == "bill" }.reduce(zero) { |sum, event| sum + event.amount.abs }
        net = inflow - outflow

        if date >= today
          running = (running || cash_on_hand) + net
        end

        Day.new(
          date: date,
          in_month: date.month == month_start.month,
          events: events.first(MAX_EVENTS_PER_DAY),
          inflow: inflow,
          outflow: outflow,
          net: net,
          running_balance: (date >= today) ? running : nil
        )
      end
    end

    def sum_money(rows, field)
      rows.reduce(zero) { |sum, day| sum + day.public_send(field) }
    end
end
