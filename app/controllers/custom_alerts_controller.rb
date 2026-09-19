class CustomAlertsController < ApplicationController
  before_action :set_alert, only: %i[update destroy]

  def index
    @custom_alerts = Current.family.custom_alerts.order(:name)
    @custom_alert = Current.family.custom_alerts.new(kind: "overspend", enabled: true)
    @breadcrumbs = [
      [ t("breadcrumbs.home"), root_path ],
      [ t("breadcrumbs.settings"), settings_profile_path ],
      [ t("custom_alerts.index.title"), nil ]
    ]
  end

  def create
    @custom_alert = Current.family.custom_alerts.new(alert_params)
    if @custom_alert.save
      redirect_to custom_alerts_path, notice: t(".created")
    else
      @custom_alerts = Current.family.custom_alerts.order(:name)
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @alert.update!(alert_params)
    redirect_to custom_alerts_path, notice: t(".updated")
  end

  def destroy
    @alert.destroy!
    redirect_to custom_alerts_path, notice: t(".destroyed")
  end

  private
    def set_alert
      @alert = Current.family.custom_alerts.find(params[:id])
    end

    def alert_params
      params.require(:custom_alert).permit(:kind, :name, :enabled, config: {})
    end
end
