class CactusIntegrationsController < ApplicationController
  before_action :ensure_can_manage_cactus_integrations

  def show
    @github_webhook_url = github_webhook_url
    @github_webhook_secret_configured = github_webhook_secret.present?
    @github_webhook_delivery_counts = Current.account.github_webhook_deliveries.group(:status).count
    @github_webhook_last_delivery = Current.account.github_webhook_deliveries.latest_first.first
    @github_webhook_failed_deliveries = Current.account.github_webhook_deliveries.failed.latest_first.limit(5)
    @github_webhook_deliveries = Current.account.github_webhook_deliveries.latest_first.limit(10)
  end

  private
    def github_webhook_secret
      Rails.application.credentials.dig(:github, :webhook_secret).presence || ENV["GITHUB_WEBHOOK_SECRET"]
    end
end
