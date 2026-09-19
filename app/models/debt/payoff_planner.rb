module Debt
  class PayoffPlanner
    STRATEGIES = %w[avalanche snowball].freeze
    MAX_MONTHS = 360
    MIN_CREDIT_PAYMENT = 25.to_d
    CREDIT_PERCENT = BigDecimal("0.02")
    PAID_OFF = BigDecimal("0.01")

    Result = Data.define(
      :strategy, :extra_payment, :rows, :months, :debt_free_on,
      :total_interest, :baseline_interest, :interest_saved, :capped, :monthly_minimums
    )
    Row = Data.define(
      :account_id, :name, :kind, :balance, :rate, :minimum,
      :order, :payoff_on, :interest_paid
    )

    def self.strategy_for(value)
      candidate = value.to_s
      STRATEGIES.include?(candidate) ? candidate : "avalanche"
    end

    def self.extra_payment_for(value)
      amount = BigDecimal(value.to_s)
      amount.negative? ? 0.to_d : amount
    rescue ArgumentError, TypeError
      0.to_d
    end

    def initialize(accounts:, currency:, strategy: "avalanche", extra_payment: 0)
      @accounts = Array(accounts)
      @currency = currency
      @strategy = self.class.strategy_for(strategy)
      @extra_payment = self.class.extra_payment_for(extra_payment)
    end

    def result
      with_extra = simulate(extra_payment)
      baseline = extra_payment.zero? ? with_extra : simulate(0)
      saved = [ baseline.total_interest.amount - with_extra.total_interest.amount, 0.to_d ].max

      Result.new(
        strategy: strategy,
        extra_payment: extra_payment,
        rows: with_extra.rows,
        months: with_extra.months,
        debt_free_on: with_extra.debt_free_on,
        total_interest: with_extra.total_interest,
        baseline_interest: baseline.total_interest,
        interest_saved: Money.new(saved, currency),
        capped: with_extra.capped,
        monthly_minimums: with_extra.monthly_minimums
      )
    end

    private
      attr_reader :accounts, :currency, :strategy, :extra_payment

      Simulation = Data.define(:rows, :months, :debt_free_on, :total_interest, :capped, :monthly_minimums)
      State = Struct.new(:id, :name, :kind, :balance, :rate, :minimum, :interest_paid, keyword_init: true)

      def simulate(extra)
        states = snapshot_states
        return empty_simulation if states.empty?

        originals = snapshot_states
        monthly_minimums = originals.sum(&:minimum)
        payoff_on = {}
        interest_by_id = Hash.new(0.to_d)
        freed_minimums = 0.to_d
        month = 0
        start = Date.current.beginning_of_month

        while states.any? && month < MAX_MONTHS
          month += 1
          due_on = start + month.months
          extra_this_month = extra.to_d + freed_minimums

          states.each do |state|
            interest = (state.balance * monthly_rate(state.rate)).round(2)
            state.balance += interest
            state.interest_paid += interest
          end

          leftover_min = 0.to_d
          states.each do |state|
            payment = [ state.minimum, state.balance ].min
            state.balance = (state.balance - payment).round(2)
            leftover_min += (state.minimum - payment) if payment < state.minimum
          end

          extra_this_month += leftover_min
          target = sort_states(states.select { |state| state.balance > PAID_OFF }).first
          if target && extra_this_month.positive?
            payment = [ extra_this_month, target.balance ].min
            target.balance = (target.balance - payment).round(2)
          end

          states.dup.each do |state|
            next if state.balance > PAID_OFF

            payoff_on[state.id] = due_on
            interest_by_id[state.id] = state.interest_paid
            freed_minimums += state.minimum
            states.delete(state)
          end
        end

        states.each { |state| interest_by_id[state.id] = state.interest_paid }

        capped = states.any?
        last_date = payoff_on.values.max
        last_date ||= start + MAX_MONTHS.months if capped

        Simulation.new(
          rows: build_rows(originals, payoff_on, interest_by_id),
          months: month,
          debt_free_on: last_date,
          total_interest: Money.new(interest_by_id.values.sum, currency),
          capped: capped,
          monthly_minimums: Money.new(monthly_minimums, currency)
        )
      end

      def empty_simulation
        Simulation.new(
          rows: [],
          months: 0,
          debt_free_on: nil,
          total_interest: Money.new(0, currency),
          capped: false,
          monthly_minimums: Money.new(0, currency)
        )
      end

      def snapshot_states
        starting_states.map do |state|
          State.new(
            id: state.id,
            name: state.name,
            kind: state.kind,
            balance: state.balance,
            rate: state.rate,
            minimum: state.minimum,
            interest_paid: 0.to_d
          )
        end
      end

      def starting_states
        @starting_states ||= accounts.filter_map do |account|
          balance = converted_balance(account)
          next if balance.nil? || balance <= 0

          rate = annual_rate(account)
          State.new(
            id: account.id,
            name: account.name,
            kind: account.accountable_type,
            balance: balance,
            rate: rate,
            minimum: minimum_payment(account, balance, rate),
            interest_paid: 0.to_d
          )
        end
      end

      def build_rows(originals, payoff_on, interest_by_id)
        sort_states(originals).each_with_index.map do |state, index|
          Row.new(
            account_id: state.id,
            name: state.name,
            kind: state.kind,
            balance: Money.new(state.balance, currency),
            rate: state.rate,
            minimum: Money.new(state.minimum, currency),
            order: index + 1,
            payoff_on: payoff_on[state.id],
            interest_paid: Money.new(interest_by_id[state.id] || 0, currency)
          )
        end
      end

      def sort_states(states)
        case strategy
        when "snowball"
          states.sort_by { |state| [ state.balance, -state.rate, state.name ] }
        else
          states.sort_by { |state| [ -state.rate, state.balance, state.name ] }
        end
      end

      def monthly_rate(annual_percent)
        (annual_percent.to_d / 100) / 12
      end

      def converted_balance(account)
        account.balance_money.exchange_to(currency).amount
      rescue Money::ConversionError
        nil
      end

      def annual_rate(account)
        case account.accountable
        when CreditCard
          account.accountable.apr.to_d
        when Loan
          loan = account.accountable
          (loan.current_variable_rate || loan.interest_rate || 0).to_d
        else
          0.to_d
        end
      end

      def minimum_payment(account, balance, rate)
        case account.accountable
        when CreditCard
          stored = account.accountable.minimum_payment
          return stored.to_d if stored.present? && stored.to_d.positive?

          [ MIN_CREDIT_PAYMENT, (balance * CREDIT_PERCENT).round(2) ].max
        when Loan
          payment = account.accountable.monthly_payment
          return payment.amount.to_d if payment&.amount&.positive?

          interest = (balance * monthly_rate(rate)).round(2)
          [ interest + (balance * BigDecimal("0.01")).round(2), 1.to_d ].max
        else
          [ (balance * CREDIT_PERCENT).round(2), 1.to_d ].max
        end
      end
  end
end
