class CactusIntegrationsController < ApplicationController
  before_action :ensure_admin

  def show
    @github_webhook_url = github_webhook_url
    @github_webhook_secret_configured = github_webhook_secret.present?
  end

  private
    def github_webhook_secret
      Rails.application.credentials.dig(:github, :webhook_secret).presence || ENV["GITHUB_WEBHOOK_SECRET"]
    end
end
