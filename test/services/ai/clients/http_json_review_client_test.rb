require "test_helper"

class Ai::Clients::HttpJsonReviewClientTest < ActiveSupport::TestCase
  test "is unavailable without endpoint" do
    client = Ai::Clients::HttpJsonReviewClient.new(endpoint: nil)

    assert_not client.available?
  end

  test "raises missing endpoint before making request" do
    client = Ai::Clients::HttpJsonReviewClient.new(endpoint: nil)

    assert_raises Ai::Clients::HttpJsonReviewClient::MissingEndpoint do
      client.review_card_quality(context: {})
    end
  end

  test "posts context and parses generic response" do
    stub_request(:post, "https://ai.example.test/review")
      .with do |request|
        body = JSON.parse(request.body)
        request.headers["Authorization"] == "Bearer secret" &&
          body["task"] == "card_quality_review" &&
          body["model"] == "custom-reviewer" &&
          body.dig("context", "card", "id") == "1"
      end
      .to_return(
        status: 200,
        body: {
          output: {
            status: "ready",
            summary: "Ready",
            missing_gate_one_fields: [],
            missing_gate_two_fields: [],
            warnings: [],
            suggestions: []
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    output = Ai::Clients::HttpJsonReviewClient.new(
      endpoint: "https://ai.example.test/review",
      api_key: "secret",
      model: "custom-reviewer"
    ).review_card_quality(context: { "card" => { "id" => "1" } })

    assert_equal "ready", output["status"]
    assert_equal "Ready", output["summary"]
  end

  test "reports missing keys" do
    stub_request(:post, "https://ai.example.test/review").to_return(status: 200, body: { output: { status: "ready" } }.to_json)

    error = assert_raises Ai::Clients::HttpJsonReviewClient::ApiError do
      Ai::Clients::HttpJsonReviewClient.new(endpoint: "https://ai.example.test/review").review_card_quality(context: {})
    end

    assert_match "missing required key", error.message
  end
end
