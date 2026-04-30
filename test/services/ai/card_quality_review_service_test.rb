require "test_helper"

class Ai::CardQualityReviewServiceTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:logo)
  end

  test "creates completed review run with missing fields and warnings" do
    assert_difference -> { AiRun.count }, +1 do
      @ai_run = Ai::CardQualityReviewService.new(@card, user: users(:david)).review
    end

    assert @ai_run.completed?
    assert_equal "needs_work", @ai_run.output["status"]
    assert_includes @ai_run.output["warnings"], "Structured resolution record is missing."
    assert_includes @ai_run.output["suggestions"], "Reference the card in a commit or PR title/body using CT-#{@card.number}."
  end

  test "uses llm client when available" do
    client = FakeReviewClient.new(
      output: {
        "status" => "needs_work",
        "summary" => "LLM reviewed the card",
        "missing_gate_one_fields" => [ "problem_description" ],
        "missing_gate_two_fields" => [],
        "warnings" => [ "Needs reporter detail" ],
        "suggestions" => [ "Ask for reproduction steps" ]
      }
    )

    ai_run = Ai::CardQualityReviewService.new(@card, user: users(:david), client: client).review

    assert ai_run.completed?
    assert_equal "LLM reviewed the card", ai_run.output["summary"]
    assert_equal "llm", ai_run.metadata["reviewer_type"]
    assert_equal "fake-model", ai_run.metadata["model"]
  end

  test "records failed review when llm client raises" do
    client = FakeReviewClient.new(error: "API unavailable")

    ai_run = Ai::CardQualityReviewService.new(@card, user: users(:david), client: client).review

    assert ai_run.failed?
    assert_equal "API unavailable", ai_run.output["error"]
    assert_equal "RuntimeError", ai_run.metadata["error_class"]
  end

  test "reports ready when structured gates and code evidence are present" do
    @card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page",
      root_cause: "Image sizing used the wrong max width",
      fix_summary: "Adjusted the card image layout",
      verification_steps: "Opened the card and confirmed the logo is readable"
    )
    @card.code_links.create!(
      provider: "github",
      external_type: "commit",
      external_id: "abc123",
      sha: "abc123",
      metadata: {}
    )

    ai_run = Ai::CardQualityReviewService.new(@card, user: users(:david)).review

    assert_equal "ready", ai_run.output["status"]
    assert_empty ai_run.output["missing_gate_one_fields"]
    assert_empty ai_run.output["missing_gate_two_fields"]
    assert_empty ai_run.output["warnings"]
  end

  class FakeReviewClient
    attr_reader :model

    def initialize(output: nil, error: nil)
      @output = output
      @error = error
      @model = "fake-model"
    end

    def available?
      true
    end

    def review_card_quality(context:)
      raise @error if @error

      @output
    end
  end
end
