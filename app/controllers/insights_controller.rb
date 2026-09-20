class InsightsController < ApplicationController
  before_action :set_insight, only: %i[acknowledge unacknowledge feedback]

  def index
    redirect_to root_path(anchor: "insights-feed")
  end

  def acknowledge
    @insight.acknowledge!
    # Both surfaces: the response carries streams for the /insights list and the
    # dashboard widget, and each page applies only the ones whose targets it has.
    # The list (not just the acknowledged card) is reloaded so its empty state
    # can take over when the last insight goes.
    load_feed
    load_widget_feed

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to root_path(anchor: "insights-feed") }
    end
  end

  def unacknowledge
    @insight.unacknowledge!
    load_feed
    load_widget_feed

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to root_path(anchor: "insights-feed") }
    end
  end

  def feedback
    @insight.record_feedback!(params[:value])
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to root_path(anchor: "insights-feed") }
    end
  end

  def refresh
    GenerateInsightsJob.perform_later(family_id: Current.family.id)

    respond_to do |format|
      # Swaps the button into its pending state; the job broadcasts the
      # refreshed list and the idle button back when it finishes.
      format.turbo_stream
      format.html { redirect_to root_path(anchor: "insights-feed"), notice: t("insights.refresh.queued") }
    end
  end

  private
    def set_insight
      @insight = Current.family.insights.find(params[:id])
    end

    def load_feed
      @insights = Current.family.insights.visible.ordered.to_a
      @unread_ids = @insights.select(&:active?).map(&:id).to_set
    end

    # Acknowledging is reachable from the dashboard widget as well as this page,
    # so the response re-renders the widget's top three. Removing a row there
    # should promote the next insight into the freed slot, not leave a gap.
    def load_widget_feed
      @feed_insights = Current.family.insights.visible.ordered.limit(Insight::FEED_LIMIT).to_a
    end

    # Turbo sends X-Sec-Purpose (the fetch spec forbids setting Sec-Purpose
    # from JS) on hover-prefetch requests.
    def prefetch_request?
      request.headers["X-Sec-Purpose"] == "prefetch" || request.headers["Sec-Purpose"].to_s.include?("prefetch")
    end
end
