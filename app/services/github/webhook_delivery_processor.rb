module Github
  class WebhookDeliveryProcessor
    def initialize(webhook_delivery)
      @webhook_delivery = webhook_delivery
    end

    def process
      webhook_delivery.mark_processing!(
        event: webhook_delivery.event,
        payload_sha256: webhook_delivery.payload_sha256,
        payload: webhook_delivery.payload
      )

      code_links = WebhookProcessor.new(
        account: webhook_delivery.account,
        event: webhook_delivery.event,
        payload: webhook_delivery.payload
      ).process

      webhook_delivery.mark_processed!(code_links.size)
      code_links
    rescue KeyError => error
      webhook_delivery.mark_failed!("Missing required GitHub payload field: #{error.key}")
      raise
    rescue StandardError => error
      webhook_delivery.mark_failed!(error.message)
      raise
    end

    private
      attr_reader :webhook_delivery
  end
end
