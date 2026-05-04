require "test_helper"

class Ai::ResolutionDraftServiceTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:logo)
  end

  test "creates completed resolution draft run from code evidence" do
    @card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      structured_summary: "Logo rendering is too small",
      domain: "ui/ux"
    )
    @card.code_links.create!(
      provider: "github",
      external_type: "pull_request",
      external_id: "42",
      repository: "cactus/fizzy",
      title: "Fix card logo sizing",
      url: "https://github.com/cactus/fizzy/pull/42",
      metadata: {}
    )

    assert_difference -> { AiRun.count }, +1 do
      @ai_run = Ai::ResolutionDraftService.new(@card, user: users(:david)).suggest
    end

    assert @ai_run.completed?
    assert_equal "resolution_draft", @ai_run.run_type
    assert_equal "suggested", @ai_run.output["status"]
    assert_match "ui/ux", @ai_run.output.dig("suggested_fields", "root_cause")
    assert_match "Fix card logo sizing", @ai_run.output.dig("suggested_fields", "fix_summary")
    assert_match "ui/ux", @ai_run.output.dig("suggested_fields", "verification_steps")
    assert_equal "deterministic", @ai_run.metadata["completed_by"]
    assert_equal "medium", @ai_run.output.dig("confidence", "resolution")
  end

  test "warns when code evidence is missing" do
    ai_run = Ai::ResolutionDraftService.new(@card, user: users(:david)).suggest

    assert_includes ai_run.output["warnings"], "No linked commit or PR evidence is present; the draft is generic and should not be accepted as-is."
    assert_equal "low", ai_run.output.dig("confidence", "resolution")
  end
end
