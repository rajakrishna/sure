# frozen_string_literal: true

class Api::V1::InboxController < Api::V1::BaseController
  before_action :ensure_read_scope

  def show
    inbox = Transaction::Inbox.new(
      family: current_resource_owner.family,
      user: current_resource_owner,
      assignee_id: params[:assignee_id]
    )
    transactions = inbox.transactions.limit(100)

    render json: {
      assigned_to_me: inbox.assigned_to_user_count,
      transactions: transactions.map { |transaction|
        entry = transaction.entry
        {
          id: transaction.id,
          name: entry&.name,
          date: entry&.date&.iso8601,
          amount: entry&.amount,
          currency: entry&.currency,
          assignee_id: transaction.assignee_id
        }
      }
    }
  end

  private
    def ensure_read_scope
      authorize_scope!(:read)
    end

end
