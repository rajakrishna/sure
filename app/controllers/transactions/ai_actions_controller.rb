class Transactions::AiActionsController < ApplicationController
  before_action :set_entry

  def create
    @transaction = @entry.transaction
    @kind = params[:kind].presence || "suggest"
    @proposal = Transaction::AiSuggestion.new(
      transaction: @transaction,
      family: Current.family,
      user: Current.user
    ).propose!(@kind)

    if @proposal.blank?
      redirect_back_fallback and return
    end

    render :show
  end

  private
    def set_entry
      @entry = Current.family.entries
        .joins(:account)
        .merge(Account.accessible_by(Current.user))
        .find(params[:transaction_id])
    end

    def redirect_back_fallback
      redirect_back fallback_location: transaction_path(@entry),
        alert: t("transactions.ai_actions.unavailable")
    end
end
