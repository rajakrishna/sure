class Transactions::ReviewsController < ApplicationController
  def create
    ids = Array(params[:transaction_ids]).presence || Array(params[:transaction_id])
    transactions = Current.family.transactions.where(id: ids)
    transactions.find_each { |transaction| transaction.mark_reviewed!(Current.user) }

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to transactions_inbox_path, notice: t(".success", count: transactions.size) }
    end
  end
end
