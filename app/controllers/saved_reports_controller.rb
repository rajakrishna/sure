class SavedReportsController < ApplicationController
  before_action :set_saved_report, only: :destroy

  def create
    report = Current.family.saved_reports.new(saved_report_params)
    report.user = Current.user

    if report.save
      redirect_to reports_path(report.to_filter_params), notice: t(".created")
    else
      redirect_to reports_path, alert: report.errors.full_messages.to_sentence
    end
  end

  def destroy
    @saved_report.destroy
    redirect_to reports_path, notice: t(".destroyed")
  end

  private
    def set_saved_report
      @saved_report = Current.family.saved_reports.find(params[:id])
    end

    def saved_report_params
      params.require(:saved_report).permit(
        :name,
        config: [ :period_type, :start_date, :end_date, :shared_view, :grouping, :filter_category_id, :filter_account_id, :filter_tag_id, { sections: [] } ]
      )
    end
end
