class Github::WebhookDeliveryRetriesController < ApplicationController
  before_action :ensure_can_manage_cactus_integrations

  def create
    webhook_delivery = Current.account.github_webhook_deliveries.find(params[:webhook_delivery_id])

    unless webhook_delivery.retryable?
      redirect_to cactus_integrations_path, alert: "Only failed GitHub deliveries with a saved payload can be retried."
      return
    end

    code_links = webhook_delivery.process!

    redirect_to cactus_integrations_path, notice: "GitHub delivery retried. Linked #{code_links.size} code references."
  rescue KeyError => error
    redirect_to cactus_integrations_path, alert: "GitHub delivery retry failed: missing required payload field #{error.key}."
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue StandardError => error
    redirect_to cactus_integrations_path, alert: "GitHub delivery retry failed: #{error.message}"
  end
end
