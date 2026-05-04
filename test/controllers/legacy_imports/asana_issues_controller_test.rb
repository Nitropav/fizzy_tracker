require "test_helper"

class LegacyImports::AsanaIssuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
    import_asana_tasks
  end

  test "index shows imported issues needing structuring" do
    get legacy_imports_asana_issues_path

    assert_response :success
    assert_match "Legacy Asana Issues", response.body
    assert_match "Imported Asana issue", response.body
    assert_match "Needs structuring", response.body
    assert_match "Gate 1 missing", response.body
    assert_match "Open Asana task", response.body
    assert_match "Structure issue", response.body
  end

  test "index can show all imported issues" do
    get legacy_imports_asana_issues_path(status: "all")

    assert_response :success
    assert_match "All (2)", response.body
    assert_match "Imported Asana issue", response.body
  end

  test "index can show structured imported issues" do
    record = Card::ResolutionRecord.find_by!(legacy_source: "asana", legacy_external_id: "asana-1")
    record.update!(gate_one_attrs)

    get legacy_imports_asana_issues_path(status: "structured")

    assert_response :success
    assert_match "Structured", response.body
    assert_match "Imported Asana issue", response.body
    assert_no_match "Gate 1 missing", response.body
  end

  test "index shows training candidate action for fully structured imported issues" do
    record = Card::ResolutionRecord.find_by!(legacy_source: "asana", legacy_external_id: "asana-2")
    record.update!(gate_one_attrs.merge(gate_two_attrs))

    get legacy_imports_asana_issues_path(status: "structured")

    assert_response :success
    assert_match "Ready for training candidate", response.body
    assert_select "form[action=?]", legacy_imports_asana_issue_training_example_path(record)
    assert_match "Generate training example", response.body
  end

  test "index shows latest structuring suggestion and apply action" do
    record = Card::ResolutionRecord.find_by!(legacy_source: "asana", legacy_external_id: "asana-2")
    ai_run = Ai::LegacyIssueStructuringService.new(record.card, user: users(:kevin)).suggest

    get legacy_imports_asana_issues_path

    assert_response :success
    assert_match "Latest AI structuring suggestion", response.body
    assert_match "Generated deterministic structuring suggestions", response.body
    assert_select "form[action=?]", apply_legacy_imports_asana_issue_structuring_suggestion_path(record, ai_run_id: ai_run.id, status: "needs_structuring")
    assert_match "Apply suggestion", response.body
  end

  test "index shows suggest structure action for incomplete imported issues" do
    record = Card::ResolutionRecord.find_by!(legacy_source: "asana", legacy_external_id: "asana-2")

    get legacy_imports_asana_issues_path

    assert_response :success
    assert_select "form[action=?]", legacy_imports_asana_issue_structuring_suggestion_path(record, status: "needs_structuring")
    assert_match "Suggest structure", response.body
  end

  test "non import users cannot review imported issues" do
    logout_and_sign_in_as :david

    get legacy_imports_asana_issues_path

    assert_response :forbidden
  end

  private
    def import_asana_tasks
      post legacy_imports_asana_path, params: {
        board_id: @board.id,
        file: fixture_file_upload("asana_tasks.json", "application/json")
      }

      assert_response :created
    end

    def gate_one_attrs
      {
        problem_description: "Imported problem",
        reproduction_steps: "Open the imported task",
        expected_behavior: "Expected behavior",
        actual_behavior: "Actual behavior",
        environment_context: "Asana legacy task"
      }
    end

    def gate_two_attrs
      {
        root_cause: "Legacy root cause",
        fix_summary: "Legacy fix",
        verification_steps: "Legacy verification",
        linked_commit_shas: [ "abc123" ]
      }
    end
end
