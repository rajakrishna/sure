class Settings::PaymentsController < ApplicationController
  layout "settings"

  def show
    redirect_to settings_profile_path
  end
end
