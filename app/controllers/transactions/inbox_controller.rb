class Transactions::InboxController < ApplicationController
  include SharedViewFilterable

  def show
    @assignee_id = params[:assignee_id]
    @inbox = Transaction::Inbox.new(
      family: Current.family,
      user: Current.user,
      assignee_id: @assignee_id,
      account_ids: shared_view.ours? ? nil : shared_view.account_ids
    )
    @transactions = @inbox.transactions.limit(100)
    @assigned_to_me = @inbox.assigned_to_user_count
    @members = Current.family.users.where.not(role: "guest").order(:first_name, :email)
    @ai_proposals = Current.family.ai_proposals.pending.where(kind: %w[categorize set_merchant split refund_match create_rule]).recent.limit(8)
    @breadcrumbs = [
      [ t("breadcrumbs.home"), root_path ],
      [ t("breadcrumbs.transactions"), transactions_path ],
      [ t("breadcrumbs.inbox"), nil ]
    ]
  end
end
