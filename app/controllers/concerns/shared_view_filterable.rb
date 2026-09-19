module SharedViewFilterable
  extend ActiveSupport::Concern

  included do
    helper_method :shared_view, :shared_view_accounts
  end

  def shared_view
    @shared_view ||= Family::SharedView.new(
      family: Current.family,
      user: Current.user,
      key: params[:view]
    )
  end

  def shared_view_accounts
    @shared_view_accounts ||= Current.user.finance_accounts.where(id: shared_view.account_ids)
  end
end
