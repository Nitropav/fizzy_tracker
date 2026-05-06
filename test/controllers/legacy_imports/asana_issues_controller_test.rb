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
    assert_match "Asana source context", response.body
    assert_match "1 attachment", response.body
    assert_match "image.png", response.body
    assert_match "Reporter added screenshot context", response.body
  end

  test "index can show all imported issues" do
    get legacy_imports_asana_issues_path(status: "all")

    assert_response :success
    assert_match "All (2)", response.body
    assert_match "Imported Asana issue", response.body
  end

  test "index paginates large legacy imports" do
    with_current_user :kevin do
      60.times do |index|
        card = @board.cards.create!(
          account: @board.account,
          creator: users(:kevin),
          status: :published,
          title: "Bulk imported Asana issue #{index}",
          description: "Bulk imported issue #{index}"
        )

        card.create_resolution_record!(
          legacy_import: true,
          legacy_source: "asana",
          legacy_external_id: "bulk-asana-#{index}",
          legacy_imported_at: index.minutes.ago,
          problem_description: "Bulk imported problem #{index}"
        )
      end
    end

    get legacy_imports_asana_issues_path(status: "all")

    assert_response :success
    assert_match "All (62)", response.body
    assert_select ".pagination-link"
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

    get legacy_imports_asana_issues_path(status: "training_candidates")

    assert_response :success
    assert_match "Training candidates (1)", response.body
    assert_match "Ready for training candidate", response.body
    assert_select "form[action=?]", legacy_imports_asana_issue_training_example_path(record)
    assert_match "Generate training example", response.body
  end

  test "index links existing training example instead of showing duplicate generation action" do
    record = Card::ResolutionRecord.find_by!(legacy_source: "asana", legacy_external_id: "asana-2")
    record.update!(gate_one_attrs.merge(gate_two_attrs))
    training_example = TrainingExamples::Generator.new(record.card).generate

    get legacy_imports_asana_issues_path(status: "training_candidates")

    assert_response :success
    assert_match "Training example: Pending review", response.body
    assert_select "a[href=?]", training_example_path(training_example), text: "Review training example"
    assert_select "form[action=?]", legacy_imports_asana_issue_training_example_path(record), count: 0
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
    users(:kevin).update!(role: :member, cactus_role: :developer)

    get legacy_imports_asana_issues_path

    assert_response :forbidden
  end

  private
    def import_asana_tasks
      perform_enqueued_jobs do
        post legacy_imports_asana_path, params: {
          board_id: @board.id,
          file: fixture_file_upload("asana_tasks.json", "application/json")
        }
      end

      asana_import = LegacyImports::AsanaImport.latest_first.first
      assert_redirected_to legacy_imports_asana_import_path(asana_import)
      assert_predicate asana_import.reload, :completed?
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
