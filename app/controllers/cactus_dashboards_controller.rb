class CactusDashboardsController < ApplicationController
  before_action :ensure_can_view_cactus_dashboard

  def show
    @metrics = CactusPipelineMetrics.new(account: Current.account, period: params[:period]).call
  end
end
