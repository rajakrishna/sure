class Assistant::Function::GetGoals < Assistant::Function
  class << self
    def name
      "get_goals"
    end

    def description
      <<~INSTRUCTIONS
        Lists the family's savings goals with live progress.

        Use this for questions like:
        - How are my goals going?
        - What's left on the vacation fund?
        - Which goals are behind?

        Returns name, status, target, current balance, progress percent,
        target date, and linked account names. Archived goals are omitted
        unless include_archived is true.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [],
      properties: {
        include_archived: {
          type: "boolean",
          description: "Include archived goals (defaults to false)"
        }
      }
    )
  end

  def call(params = {})
    scope = family.goals.includes(:linked_accounts, :open_pledges)
    scope = scope.where.not(state: "archived") unless ActiveModel::Type::Boolean.new.cast(params["include_archived"])

    {
      goals: scope.map { |goal| serialize_goal(goal) }
    }
  end

  private
    def serialize_goal(goal)
      {
        id: goal.id,
        name: goal.name,
        state: goal.state,
        status: goal.display_status,
        target_amount: goal.target_amount_money.format,
        current_balance: goal.current_balance_money.format,
        remaining_amount: goal.remaining_amount_money.format,
        progress_percent: goal.progress_percent,
        target_date: goal.target_date&.iso8601,
        linked_account_names: goal.linked_accounts.map(&:name),
        open_pledge_count: goal.open_pledges.size
      }
    end
end
