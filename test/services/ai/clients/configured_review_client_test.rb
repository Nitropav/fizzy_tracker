require "test_helper"

class Ai::Clients::ConfiguredReviewClientTest < ActiveSupport::TestCase
  setup do
    @previous_endpoint = ENV["AI_REVIEW_ENDPOINT"]
    @previous_openai_key = ENV["OPENAI_API_KEY"]
  end

  teardown do
    ENV["AI_REVIEW_ENDPOINT"] = @previous_endpoint
    ENV["OPENAI_API_KEY"] = @previous_openai_key
  end

  test "uses generic http json client when endpoint is configured" do
    ENV["AI_REVIEW_ENDPOINT"] = "https://ai.example.test/review"
    ENV["OPENAI_API_KEY"] = "openai-key"

    assert_instance_of Ai::Clients::HttpJsonReviewClient, Ai::Clients::ConfiguredReviewClient.build
  end

  test "falls back to openai client when only openai key is configured" do
    ENV.delete("AI_REVIEW_ENDPOINT")
    ENV["OPENAI_API_KEY"] = "openai-key"

    assert_instance_of Ai::Clients::OpenaiResponsesClient, Ai::Clients::ConfiguredReviewClient.build
  end

  test "uses unavailable client when no external provider is configured" do
    ENV.delete("AI_REVIEW_ENDPOINT")
    ENV.delete("OPENAI_API_KEY")

    assert_instance_of Ai::Clients::UnavailableReviewClient, Ai::Clients::ConfiguredReviewClient.build
  end
end
