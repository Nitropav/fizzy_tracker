require "test_helper"

class CactusEndToEndWorkflowTest < ActionDispatch::IntegrationTest
  test "legacy Asana issue flows into an approved and exported training example" do
    sign_in_as :kevin
    board = boards(:writebook)

    assert_difference -> { Card.count }, +2 do
      assert_difference -> { Card::ResolutionRecord.where(legacy_import: true).count }, +2 do
        perform_enqueued_jobs do
          post legacy_imports_asana_path, params: {
            board_id: board.id,
            file: fixture_file_upload("asana_tasks.json", "application/json")
          }
        end
      end
    end

    asana_import = LegacyImports::AsanaImport.latest_first.first
    assert_redirected_to legacy_imports_asana_import_path(asana_import)
    assert_predicate asana_import.reload, :completed?

    record = Card::ResolutionRecord.find_by!(legacy_source: "asana", legacy_external_id: "asana-1")
    card = record.card
    assert_equal "needs_info", card.cactus_workflow_state
    assert_predicate record, :needs_structuring?

    put card_resolution_record_path(card), params: {
      card_resolution_record: {
        reproduction_steps: "Open the imported quote preview",
        expected_behavior: "Glass should be visible in the quote preview",
        actual_behavior: "Glass is missing from the quote preview",
        environment_context: "ES Windows support project",
        priority: "high",
        category: "bug",
        domain: "glass visibility",
        severity: "degrades experience"
      }
    }, as: :json

    assert_response :success
    assert_predicate record.reload, :gate_one_complete?
    assert_not_predicate record, :needs_structuring?
    assert_equal "open", card.reload.cactus_workflow_state

    post card_triage_path(card, column_id: columns(:writebook_in_progress).id), as: :json
    assert_response :no_content
    assert_equal "in_progress", card.reload.cactus_workflow_state

    logout_and_sign_in_as :david

    post card_self_assignment_path(card), as: :json
    assert_response :no_content
    assert card.reload.assigned_to?(users(:david))

    put card_resolution_record_path(card), params: {
      card_resolution_record: {
        root_cause: "The preview renderer skipped imported glass visibility constraints.",
        fix_summary: "Updated preview filtering so compatible glass remains visible.",
        verification_steps: "Opened the quote preview and confirmed compatible glass is displayed.",
        linked_commit_shas: [ "abc123" ],
        linked_pr_urls: [ "https://github.com/cactuscorp/fizzy_tracker/pull/123" ]
      }
    }, as: :json

    assert_response :success
    assert_predicate record.reload, :gate_two_complete?
    assert_equal "needs_review", card.reload.cactus_workflow_state

    assert_difference -> { TrainingExample.count }, +1 do
      post card_resolution_path(card), as: :json
    end

    assert_response :created
    training_example = card.training_examples.latest_first.first
    assert_equal training_example.id, response.parsed_body["training_example_id"]
    assert_predicate card.reload, :closed?
    assert_predicate training_example, :pending_review?
    assert_equal "Imported Asana issue", training_example.problem_summary
    assert_equal "glass visibility", training_example.metadata["domain"]
    assert_equal [ "abc123" ], training_example.metadata["commit_shas"]

    logout_and_sign_in_as :jason

    post approve_training_example_path(training_example), params: {
      review_notes: "Approved after end-to-end regression coverage."
    }
    assert_redirected_to training_example
    assert_predicate training_example.reload, :approved?
    assert_equal users(:jason), training_example.reviewed_by

    perform_enqueued_jobs do
      post export_training_examples_path
    end

    assert_redirected_to training_example_exports_path
    training_example_export = TrainingExampleExport.latest_first.first
    assert_predicate training_example_export.reload, :completed?
    assert_predicate training_example_export.file, :attached?
    assert_predicate training_example.reload, :exported?

    get training_example_export_path(training_example_export)
    assert_response :success

    payload = JSON.parse(response.body.lines.first)
    assert_equal training_example.id, payload.dig("metadata", "training_example_id")
    assert_equal card.number, payload.dig("metadata", "card_number")
    assert_equal [ "abc123" ], payload.dig("metadata", "commit_shas")
    assert_equal "assistant", payload.dig("messages", 2, "role")
  end
end
