require "test_helper"

class LegacyImports::AsanaStructuringSuggestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
    import_asana_tasks
    @record = Card::ResolutionRecord.find_by!(legacy_source: "asana", legacy_external_id: "asana-2")
  end

  test "create generates legacy structuring suggestion" do
    assert_enqueued_with(job: Ai::RunJob) do
      assert_difference -> { @record.card.ai_runs.legacy_issue_structurings.count }, +1 do
        post legacy_imports_asana_issue_structuring_suggestion_path(@record)
      end
    end

    assert_redirected_to legacy_imports_asana_issues_path(status: "needs_structuring")
    assert_equal "Legacy structuring suggestion queued.", flash[:notice]

    ai_run = @record.card.ai_runs.legacy_issue_structurings.latest_first.first
    assert ai_run.pending?
  end

  test "queued legacy structuring suggestion completes in background job" do
    perform_enqueued_jobs do
      post legacy_imports_asana_issue_structuring_suggestion_path(@record)
    end

    ai_run = @record.card.ai_runs.legacy_issue_structurings.latest_first.first
    assert ai_run.completed?
    assert_equal "suggested", ai_run.output["status"]
    assert_equal "Legacy task was marked complete in Asana. Summarize the actual fix from the historical implementation before approval.", ai_run.output.dig("suggested_fields", "fix_summary")
  end

  test "apply fills only blank fields from suggestion" do
    @record.update!(problem_description: "Do not overwrite this problem")
    ai_run = Ai::LegacyIssueStructuringService.new(@record.card, user: users(:kevin)).suggest

    patch_path = apply_legacy_imports_asana_issue_structuring_suggestion_path(@record, ai_run_id: ai_run.id)

    post patch_path

    assert_redirected_to legacy_imports_asana_issues_path(status: "needs_structuring")
    assert_equal "Applied 7 suggested fields.", flash[:notice]

    @record.reload
    assert_equal "Do not overwrite this problem", @record.problem_description
    assert_equal "Review the imported Asana task and reproduce the reported behavior in the referenced ES Windows workflow.", @record.reproduction_steps
    assert_equal "Legacy task was marked complete in Asana. Confirm the historical root cause from linked implementation notes or commits before approval.", @record.root_cause
    assert_equal "needs investigation", @record.severity
    assert ai_run.reload.applied?
    assert_not ai_run.active_suggestion?
  end

  test "apply cannot use another card suggestion" do
    other_record = Card::ResolutionRecord.find_by!(legacy_source: "asana", legacy_external_id: "asana-1")
    ai_run = Ai::LegacyIssueStructuringService.new(other_record.card, user: users(:kevin)).suggest

    post apply_legacy_imports_asana_issue_structuring_suggestion_path(@record, ai_run_id: ai_run.id)

    assert_response :not_found
  end

  test "non import users cannot create or apply suggestions" do
    ai_run = Ai::LegacyIssueStructuringService.new(@record.card, user: users(:kevin)).suggest
    users(:kevin).update!(role: :member, cactus_role: :developer)

    assert_no_difference -> { AiRun.count } do
      post legacy_imports_asana_issue_structuring_suggestion_path(@record)
    end

    assert_response :forbidden

    post apply_legacy_imports_asana_issue_structuring_suggestion_path(@record, ai_run_id: ai_run.id)

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
end
