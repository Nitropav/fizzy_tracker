require "test_helper"

class Ai::Clients::OpenaiResponsesClientTest < ActiveSupport::TestCase
  test "is unavailable without api key" do
    client = Ai::Clients::OpenaiResponsesClient.new(api_key: nil)

    assert_not client.available?
  end

  test "raises missing api key before making request" do
    client = Ai::Clients::OpenaiResponsesClient.new(api_key: nil)

    assert_raises Ai::Clients::OpenaiResponsesClient::MissingApiKey do
      client.review_card_quality(context: {})
    end
  end

  test "parses structured output from responses api" do
    stub_request(:post, "https://api.openai.com/v1/responses")
      .to_return(
        status: 200,
        body: {
          output: [
            {
              content: [
                {
                  type: "output_text",
                  text: {
                    status: "ready",
                    summary: "Ready",
                    missing_gate_one_fields: [],
                    missing_gate_two_fields: [],
                    warnings: [],
                    suggestions: []
                  }.to_json
                }
              ]
            }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    output = Ai::Clients::OpenaiResponsesClient.new(api_key: "key", model: "test-model").review_card_quality(context: { "card" => { "id" => "1" } })

    assert_equal "ready", output["status"]
    assert_equal "Ready", output["summary"]
  end
end
