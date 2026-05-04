require "test_helper"

class Github::WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @secret = "test-secret"
    @previous_secret = ENV["GITHUB_WEBHOOK_SECRET"]
    ENV["GITHUB_WEBHOOK_SECRET"] = @secret
  end

  teardown do
    ENV["GITHUB_WEBHOOK_SECRET"] = @previous_secret
  end

  test "accepts signed push webhook and links commits" do
    card = cards(:logo)
    payload = {
      ref: "refs/heads/main",
      repository: { full_name: "cactus/fizzy_tracker" },
      commits: [
        {
          id: "abc123",
          message: "Fix CT-#{card.number}",
          url: "https://github.com/cactus/fizzy_tracker/commit/abc123"
        }
      ]
    }.to_json

    assert_difference -> { card.code_links.count }, +1 do
      assert_difference -> { Github::WebhookDelivery.count }, +1 do
        post github_webhook_path, params: payload, headers: github_headers(payload, event: "push", delivery_id: "delivery-1")
      end
    end

    assert_response :accepted
    assert_equal 1, @response.parsed_body["linked_code_references"]

    delivery = Github::WebhookDelivery.last
    assert_equal "delivery-1", delivery.delivery_id
    assert_equal "push", delivery.event
    assert delivery.processed?
    assert_equal 1, delivery.linked_code_references_count
    assert_equal "refs/heads/main", delivery.payload["ref"]
  end

  test "accepts duplicate delivery without reprocessing links" do
    card = cards(:logo)
    payload = {
      ref: "refs/heads/main",
      repository: { full_name: "cactus/fizzy_tracker" },
      commits: [
        {
          id: "abc123",
          message: "Fix CT-#{card.number}",
          url: "https://github.com/cactus/fizzy_tracker/commit/abc123"
        }
      ]
    }.to_json

    post github_webhook_path, params: payload, headers: github_headers(payload, event: "push", delivery_id: "delivery-duplicate")
    assert_response :accepted

    assert_no_difference -> { card.code_links.count } do
      assert_no_difference -> { Github::WebhookDelivery.count } do
        post github_webhook_path, params: payload, headers: github_headers(payload, event: "push", delivery_id: "delivery-duplicate")
      end
    end

    assert_response :accepted
    assert_equal true, @response.parsed_body["duplicate"]
    assert_equal 1, @response.parsed_body["linked_code_references"]
  end

  test "returns bad request when delivery id is missing" do
    payload = { commits: [] }.to_json

    post github_webhook_path, params: payload, headers: github_headers(payload, event: "push").except("X-GitHub-Delivery")

    assert_response :bad_request
    assert_equal "Missing GitHub delivery id", @response.parsed_body["error"]
  end

  test "returns bad request when event is missing" do
    payload = { commits: [] }.to_json

    post github_webhook_path, params: payload, headers: github_headers(payload, event: "push", delivery_id: "delivery-missing-event").except("X-GitHub-Event")

    assert_response :bad_request
    assert_equal "Missing GitHub event", @response.parsed_body["error"]
  end

  test "records failed delivery when required payload field is missing" do
    card = cards(:logo)
    payload = {
      ref: "refs/heads/main",
      repository: { full_name: "cactus/fizzy_tracker" },
      commits: [
        {
          message: "Fix CT-#{card.number}",
          url: "https://github.com/cactus/fizzy_tracker/commit/abc123"
        }
      ]
    }.to_json

    assert_no_difference -> { card.code_links.count } do
      assert_difference -> { Github::WebhookDelivery.count }, +1 do
        post github_webhook_path, params: payload, headers: github_headers(payload, event: "push", delivery_id: "delivery-missing-field")
      end
    end

    assert_response :unprocessable_entity
    assert_match "Missing required GitHub payload field", @response.parsed_body["error"]

    delivery = Github::WebhookDelivery.last
    assert_equal "delivery-missing-field", delivery.delivery_id
    assert delivery.failed?
    assert_match "Missing required GitHub payload field", delivery.error_message
    assert_equal "refs/heads/main", delivery.payload["ref"]
  end

  test "rejects invalid signature" do
    payload = { commits: [] }.to_json

    post github_webhook_path, params: payload, headers: {
      "CONTENT_TYPE" => "application/json",
      "X-GitHub-Event" => "push",
      "X-Hub-Signature-256" => "sha256=bad"
    }

    assert_response :unauthorized
    assert_equal "Invalid GitHub webhook signature", @response.parsed_body["error"]
  end

  test "rejects missing signature" do
    payload = { commits: [] }.to_json

    post github_webhook_path, params: payload, headers: github_headers(payload, event: "push", delivery_id: "delivery-missing-signature").except("X-Hub-Signature-256")

    assert_response :unauthorized
    assert_equal "Missing GitHub webhook signature", @response.parsed_body["error"]
  end

  test "returns service unavailable when webhook secret is missing" do
    ENV.delete("GITHUB_WEBHOOK_SECRET")
    Rails.application.credentials.stubs(:dig).with(:github, :webhook_secret).returns(nil)
    payload = { commits: [] }.to_json

    post github_webhook_path, params: payload, headers: github_headers(payload, event: "push", delivery_id: "delivery-no-secret")

    assert_response :service_unavailable
    assert_equal "GitHub webhook secret is not configured", @response.parsed_body["error"]
  end

  test "returns bad request for invalid json" do
    payload = "{"

    assert_difference -> { Github::WebhookDelivery.count }, +1 do
      post github_webhook_path, params: payload, headers: github_headers(payload, event: "push", delivery_id: "delivery-invalid-json")
    end

    assert_response :bad_request

    delivery = Github::WebhookDelivery.last
    assert_equal "delivery-invalid-json", delivery.delivery_id
    assert delivery.failed?
    assert_equal "Invalid JSON payload", delivery.error_message
  end

  test "records failed delivery when processing raises unexpectedly" do
    payload = {
      ref: "refs/heads/main",
      repository: { full_name: "cactus/fizzy_tracker" },
      commits: []
    }.to_json
    Github::WebhookProcessor.any_instance.stubs(:process).raises(StandardError, "boom")

    assert_difference -> { Github::WebhookDelivery.count }, +1 do
      post github_webhook_path, params: payload, headers: github_headers(payload, event: "push", delivery_id: "delivery-processing-error")
    end

    assert_response :internal_server_error
    assert_equal "GitHub webhook processing failed", @response.parsed_body["error"]

    delivery = Github::WebhookDelivery.last
    assert_equal "delivery-processing-error", delivery.delivery_id
    assert delivery.failed?
    assert_equal "boom", delivery.error_message
  end

  private
    def github_headers(payload, event:, delivery_id: SecureRandom.uuid)
      {
        "CONTENT_TYPE" => "application/json",
        "X-GitHub-Event" => event,
        "X-GitHub-Delivery" => delivery_id,
        "X-Hub-Signature-256" => "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', @secret, payload)}"
      }
    end
end
