require "test_helper"

class CactusIntegrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show is visible to admins" do
    get cactus_integrations_path

    assert_response :success
    assert_match "Cactus Integrations", response.body
    assert_match "GitHub webhook", response.body
    assert_match github_webhook_url, response.body
    assert_match "CT-&lt;issue number&gt;", response.body
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

  test "non admins cannot access integrations" do
    logout_and_sign_in_as :david

    get cactus_integrations_path

    assert_response :forbidden
  end
end
