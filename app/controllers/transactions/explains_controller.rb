class Transactions::ExplainsController < ApplicationController
  before_action :set_entry

  def show
    @transaction = @entry.transaction
    @explanation = Transaction::AiSuggestion.new(
      transaction: @transaction,
      family: Current.family,
      user: Current.user
    ).explain
  end

  private
    def set_entry
      @entry = Current.family.entries
        .joins(:account)
        .merge(Account.accessible_by(Current.user))
        .find(params[:transaction_id])
    end
end
