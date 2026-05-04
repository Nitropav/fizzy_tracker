class Github::WebhooksController < ApplicationController
  allow_unauthenticated_access only: :create
  skip_forgery_protection only: :create

  def create
    payload_body = request.raw_post
    return render_webhook_error("GitHub webhook secret is not configured", :service_unavailable) if github_webhook_secret.blank?
    return render_webhook_error("Missing GitHub webhook signature", :unauthorized) if github_signature.blank?
    return render_webhook_error("Invalid GitHub webhook signature", :unauthorized) unless valid_signature?(payload_body)
    return render json: { error: "Missing GitHub delivery id" }, status: :bad_request if github_delivery_id.blank?
    return render json: { error: "Missing GitHub event" }, status: :bad_request if github_event.blank?

    payload = JSON.parse(payload_body)
    webhook_delivery = find_or_initialize_webhook_delivery(payload_body, payload)

    if webhook_delivery.processed?
      return render json: {
        linked_code_references: webhook_delivery.linked_code_references_count,
        duplicate: true
      }, status: :accepted
    end

    webhook_delivery.assign_attributes(
      event: github_event,
      payload_sha256: payload_sha256(payload_body),
      payload: payload
    )
    code_links = webhook_delivery.process!

    render json: { linked_code_references: code_links.size }, status: :accepted
  rescue JSON::ParserError
    record_failed_delivery(payload_body, {}, "Invalid JSON payload")
    render json: { error: "Invalid JSON payload" }, status: :bad_request
  rescue KeyError => error
    render json: { error: "Missing required GitHub payload field: #{error.key}" }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique
    retry
  rescue StandardError => error
    Rails.logger.error("[GitHub Webhook] #{error.class}: #{error.message}")
    render json: { error: "GitHub webhook processing failed" }, status: :internal_server_error
  end

  private
    def valid_signature?(payload)
      Github::WebhookSignatureVerifier.new(
        payload: payload,
        signature: github_signature,
        secret: github_webhook_secret
      ).valid?
    end

    def github_webhook_secret
      Rails.application.credentials.dig(:github, :webhook_secret).presence || ENV["GITHUB_WEBHOOK_SECRET"]
    end

    def github_signature
      request.headers[Github::WebhookSignatureVerifier::SIGNATURE_HEADER].to_s
    end

    def find_or_initialize_webhook_delivery(payload_body, payload)
      Github::WebhookDelivery.find_or_initialize_by(
        account: Current.account,
        delivery_id: github_delivery_id
      ) do |webhook_delivery|
        webhook_delivery.event = github_event
        webhook_delivery.payload_sha256 = payload_sha256(payload_body)
        webhook_delivery.payload = payload
      end
    end

    def record_failed_delivery(payload_body, payload, message)
      return if github_delivery_id.blank? || github_event.blank?

      Github::WebhookDelivery.find_or_initialize_by(
        account: Current.account,
        delivery_id: github_delivery_id
      ).tap do |webhook_delivery|
        webhook_delivery.event = github_event
        webhook_delivery.payload_sha256 = payload_sha256(payload_body)
        webhook_delivery.payload = payload
        webhook_delivery.save! if webhook_delivery.new_record? || webhook_delivery.changed?
        webhook_delivery.mark_failed!(message)
      end
    end

    def github_event
      request.headers["X-GitHub-Event"].to_s
    end

    def github_delivery_id
      request.headers["X-GitHub-Delivery"].to_s
    end

    def payload_sha256(payload)
      Digest::SHA256.hexdigest(payload)
    end

    def render_webhook_error(message, status)
      render json: { error: message }, status: status
    end
end
