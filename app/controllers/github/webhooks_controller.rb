class Github::WebhooksController < ApplicationController
  allow_unauthenticated_access only: :create
  skip_forgery_protection only: :create

  def create
    payload_body = request.raw_post
    return head :unauthorized unless valid_signature?(payload_body)

    payload = JSON.parse(payload_body)
    code_links = Github::WebhookProcessor.new(
      account: Current.account,
      event: request.headers["X-GitHub-Event"],
      payload: payload
    ).process

    render json: { linked_code_references: code_links.size }, status: :accepted
  rescue JSON::ParserError
    render json: { error: "Invalid JSON payload" }, status: :bad_request
  rescue KeyError => error
    render json: { error: "Missing required GitHub payload field: #{error.key}" }, status: :unprocessable_entity
  end

  private
    def valid_signature?(payload)
      Github::WebhookSignatureVerifier.new(
        payload: payload,
        signature: request.headers[Github::WebhookSignatureVerifier::SIGNATURE_HEADER],
        secret: github_webhook_secret
      ).valid?
    end

    def github_webhook_secret
      Rails.application.credentials.dig(:github, :webhook_secret).presence || ENV["GITHUB_WEBHOOK_SECRET"]
    end
end
