require "test_helper"

class Ai::LegacyIssueStructuringServiceTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:logo)
    @record = @card.create_resolution_record!(
      legacy_import: true,
      legacy_source: "asana",
      legacy_external_id: "asana-ai-1",
      legacy_imported_at: Time.current,
      legacy_metadata: {
        "completed" => true,
        "workspace" => { "name" => "ES Windows" },
        "projects" => [ { "name" => "Pricing" } ],
        "tags" => [ { "name" => "pricing" } ]
      },
      problem_description: "Old pricing issue",
      structured_summary: "Old pricing issue"
    )
  end

  test "creates completed legacy structuring run with suggested fields" do
    assert_difference -> { AiRun.count }, +1 do
      @ai_run = Ai::LegacyIssueStructuringService.new(@card, user: users(:david)).suggest
    end

    assert @ai_run.completed?
    assert_equal "legacy_issue_structuring", @ai_run.run_type
    assert_equal "suggested", @ai_run.output["status"]
    assert_equal "pricing", @ai_run.output.dig("suggested_fields", "domain")
    assert_equal "Legacy task was marked complete in Asana. Confirm the historical root cause from linked implementation notes or commits before approval.", @ai_run.output.dig("suggested_fields", "root_cause")
    assert_includes @ai_run.output["warnings"], "Gate 2 suggestions are placeholders because the imported Asana task has no linked code evidence."
    assert_equal "deterministic", @ai_run.metadata["completed_by"]
  end
end
