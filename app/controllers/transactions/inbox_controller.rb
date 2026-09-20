class Transactions::InboxController < ApplicationController
  include SharedViewFilterable

  def show
    redirect_to ai_proposals_path
  end
end
