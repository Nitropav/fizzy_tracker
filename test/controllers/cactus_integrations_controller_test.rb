require "test_helper"

class CactusIntegrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show is visible to admins" do
    accounts("37s").github_webhook_deliveries.create!(
      delivery_id: "delivery-1",
      event: "push",
      status: "processed",
      payload_sha256: Digest::SHA256.hexdigest("{}"),
      payload: { "ref" => "refs/heads/main" },
      linked_code_references_count: 2,
      processed_at: Time.current
    )
    accounts("37s").github_webhook_deliveries.create!(
      delivery_id: "delivery-failed",
      event: "pull_request",
      status: "failed",
      payload_sha256: Digest::SHA256.hexdigest("{\"bad\":true}"),
      payload: { "bad" => true },
      error_message: "Missing required GitHub payload field: number",
      processed_at: Time.current
    )

    get cactus_integrations_path

    assert_response :success
    assert_match "Cactus Integrations", response.body
    assert_match "GitHub webhook", response.body
    assert_match github_webhook_url, response.body
    assert_match "CT-&lt;issue number&gt;", response.body
    assert_match "Setup checklist", response.body
    assert_match "Required GitHub events", response.body
    assert_match "Pushes", response.body
    assert_match "Pull requests", response.body
    assert_match "Security and error behavior", response.body
    assert_match "invalid JSON or processing errors are stored as failed deliveries", response.body
    assert_match "Reference examples", response.body
    assert_match "fix/ct-1234-price-cache", response.body
    assert_match "Failed GitHub deliveries", response.body
    assert_match "delivery-failed", response.body
    assert_match "Missing required GitHub payload field", response.body
    assert_match "Retry", response.body
    assert_match "Payload SHA", response.body
    assert_match "Recent GitHub deliveries", response.body
    assert_match "delivery-1", response.body
    assert_match "Asana import", response.body
  end

  test "show reports configured github secret" do
    previous_secret = ENV["GITHUB_WEBHOOK_SECRET"]
    ENV["GITHUB_WEBHOOK_SECRET"] = "configured-secret"

    get cactus_integrations_path

    assert_response :success
    assert_match "Secret configured", response.body
  ensure
    ENV["GITHUB_WEBHOOK_SECRET"] = previous_secret
  end

  test "show reports empty github delivery state" do
    get cactus_integrations_path

    assert_response :success
    assert_match "None yet", response.body
    assert_match "No GitHub webhook deliveries have been received yet.", response.body
  end

  test "non admins cannot access integrations" do
    logout_and_sign_in_as :david

    get cactus_integrations_path

    assert_response :forbidden
    assert_match "Access denied", response.body
  end

  test "cactus reviewers cannot access integrations" do
    users(:david).update!(cactus_role: :reviewer)
    logout_and_sign_in_as :david

    get cactus_integrations_path

    assert_response :forbidden
    assert_match "Access denied", response.body
  end
end
