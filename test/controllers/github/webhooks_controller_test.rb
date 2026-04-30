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
      post github_webhook_path, params: payload, headers: github_headers(payload, event: "push")
    end

    assert_response :accepted
    assert_equal 1, @response.parsed_body["linked_code_references"]
  end

  test "rejects invalid signature" do
    payload = { commits: [] }.to_json

    post github_webhook_path, params: payload, headers: {
      "CONTENT_TYPE" => "application/json",
      "X-GitHub-Event" => "push",
      "X-Hub-Signature-256" => "sha256=bad"
    }

    assert_response :unauthorized
  end

  test "returns bad request for invalid json" do
    payload = "{"

    post github_webhook_path, params: payload, headers: github_headers(payload, event: "push")

    assert_response :bad_request
  end

  private
    def github_headers(payload, event:)
      {
        "CONTENT_TYPE" => "application/json",
        "X-GitHub-Event" => event,
        "X-Hub-Signature-256" => "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', @secret, payload)}"
      }
    end
end
