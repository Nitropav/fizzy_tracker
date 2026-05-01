class CactusDashboardsController < ApplicationController
  before_action :ensure_admin

  def show
    @metrics = CactusPipelineMetrics.new(account: Current.account).call
  end
end
