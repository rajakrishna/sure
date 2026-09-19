# frozen_string_literal: true

class Api::V1::SavedReportsController < Api::V1::BaseController
  before_action :ensure_read_scope, only: :index
  before_action :ensure_draft_write_scope, only: :create
  before_action :require_preview_features_for_api

  def index
    reports = current_resource_owner.family.saved_reports.order(:name)

    render json: { saved_reports: reports.map { |report| serialize(report) } }
  end

  def create
    report = current_resource_owner.family.saved_reports.new(saved_report_params)
    report.user = current_resource_owner

    if report.save
      render json: { saved_report: serialize(report) }, status: :created
    else
      render json: { error: "invalid_params", message: report.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private
    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_draft_write_scope
      authorize_scope!(:draft_write)
    end

    def require_preview_features_for_api
      return if current_resource_owner.preview_features_enabled?

      render_json(
        { error: "feature_disabled", message: "Preview features are not enabled for this user" },
        status: :forbidden
      )
    end

    def saved_report_params
      params.require(:saved_report).permit(
        :name,
        config: [ :period_type, :start_date, :end_date, :shared_view, :grouping, :filter_category_id, :filter_account_id, :filter_tag_id, { sections: [] } ]
      )
    end

    def serialize(report)
      {
        id: report.id,
        name: report.name,
        period_type: report.period_type,
        sections: report.sections,
        grouping: report.grouping,
        shared_view: report.shared_view
      }
    end
end
