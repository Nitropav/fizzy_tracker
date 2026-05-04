require "test_helper"

class LegacyImports::AsanaTrainingExamplesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
    import_asana_tasks
    @record = Card::ResolutionRecord.find_by!(legacy_source: "asana", legacy_external_id: "asana-2")
  end

  test "create generates pending review training example for structured legacy issue" do
    @record.update!(gate_one_attrs.merge(gate_two_attrs))

    assert_difference -> { TrainingExample.count }, +1 do
      post legacy_imports_asana_issue_training_example_path(@record)
    end

    training_example = @record.card.training_examples.latest_first.first
    assert_redirected_to training_example
    assert training_example.pending_review?
    assert_equal "Imported resolved issue", training_example.problem_summary
    assert_equal "Legacy root cause", training_example.root_cause
    assert_equal "Legacy fix", training_example.resolution_summary
  end

  test "create does not duplicate existing draft or pending training example" do
    @record.update!(gate_one_attrs.merge(gate_two_attrs))
    existing = @record.card.training_examples.create!(
      account: @record.account,
      status: :draft,
      input_context: { "stale" => true },
      metadata: { "stale" => true }
    )

    assert_no_difference -> { TrainingExample.count } do
      post legacy_imports_asana_issue_training_example_path(@record)
    end

    assert_redirected_to existing
    assert existing.reload.pending_review?
  end

  test "create blocks incomplete legacy issue" do
    assert_no_difference -> { TrainingExample.count } do
      post legacy_imports_asana_issue_training_example_path(@record)
    end

    assert_redirected_to legacy_imports_asana_issues_path(status: "needs_structuring")
    assert_equal "Complete legacy issue structure before generating a training example. Missing: Gate 1 reproduction steps, Gate 1 expected behavior, Gate 1 actual behavior, Gate 2 root cause, Gate 2 fix summary, and Gate 2 verification steps.", flash[:alert]
  end

  test "create cannot target another account legacy record" do
    other_record = Card::ResolutionRecord.create!(
      account: accounts(:initech),
      card: cards(:radio),
      legacy_import: true,
      legacy_source: "asana",
      legacy_external_id: "other-asana",
      legacy_imported_at: Time.current
    )

    post legacy_imports_asana_issue_training_example_path(other_record)

    assert_response :not_found
  end

  test "non import users cannot generate legacy training examples" do
    @record.update!(gate_one_attrs.merge(gate_two_attrs))
    logout_and_sign_in_as :david

    assert_no_difference -> { TrainingExample.count } do
      post legacy_imports_asana_issue_training_example_path(@record)
    end

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
        problem_description: "Imported resolved issue",
        reproduction_steps: "Open the old quote",
        expected_behavior: "Pricing should be correct",
        actual_behavior: "Pricing was wrong",
        environment_context: "Legacy Asana task",
        structured_summary: "Imported resolved issue"
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
