require "test_helper"

class Ai::DuplicateIssueSuggestionServiceTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:logo)
    @candidate = cards(:text)
  end

  test "creates duplicate suggestion run with similar candidates" do
    @card.update!(
      title: "Pricing total is wrong on sales document",
      description: "Customer sees the wrong total when opening a sales document."
    )
    @card.create_resolution_record!(
      problem_description: "Wrong sales document total",
      domain: "pricing",
      category: "bug"
    )

    @candidate.update!(
      title: "Wrong pricing total in sales document",
      description: "The sales document total does not match the expected pricing."
    )
    @candidate.create_resolution_record!(
      problem_description: "Pricing total mismatch",
      domain: "pricing",
      category: "bug"
    )

    assert_difference -> { AiRun.count }, +1 do
      @ai_run = Ai::DuplicateIssueSuggestionService.new(@card, user: users(:david)).suggest
    end

    assert @ai_run.completed?
    assert_equal "duplicate_issue_suggestion", @ai_run.run_type
    assert_equal "candidates_found", @ai_run.output["status"]
    assert_equal @candidate.number, @ai_run.output.dig("candidates", 0, "number")
    assert_includes @ai_run.output.dig("candidates", 0, "reasons"), "same domain: pricing"
  end

  test "returns no candidates when similarity is weak" do
    @card.update!(title: "Pricing total is wrong")
    @candidate.update!(title: "Unrelated onboarding copy")

    ai_run = Ai::DuplicateIssueSuggestionService.new(@card, user: users(:david)).suggest

    assert_equal "no_candidates", ai_run.output["status"]
    assert_empty ai_run.output["candidates"]
  end
end
