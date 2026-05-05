require "test_helper"

class CactusFullWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
    @in_progress_column = columns(:writebook_in_progress)
  end

  test "issue moves from intake to resolved training corpus export" do
    assert_difference -> { Card.count }, +1 do
      assert_difference -> { Card::ResolutionRecord.count }, +1 do
        post cactus_issues_path, params: {
          cactus_issue: {
            board_id: @board.id,
            title: "Checkout subtotal changes after refresh",
            priority: "high",
            problem_description: "The customer subtotal changes after refreshing the quote.",
            reproduction_steps: "Open a quote\nRefresh the page\nCompare the subtotal",
            expected_behavior: "The subtotal should stay the same after refresh.",
            actual_behavior: "The subtotal changes after refresh.",
            environment_context: "Customer portal quote screen in Chrome",
            description: "<p>Reporter attached the quote screenshot.</p>"
          }
        }
      end
    end

    card = Card.order(:created_at).last
    record = card.resolution_record

    assert_redirected_to card_path(card)
    assert_equal @board, card.board
    assert_equal "open", card.cactus_workflow_state
    assert record.gate_one_complete?
    assert_not record.gate_two_complete?

    post card_triage_path(card, column_id: @in_progress_column.id), as: :json

    assert_response :no_content
    assert_equal @in_progress_column, card.reload.column
    assert_equal "in_progress", card.cactus_workflow_state

    post card_self_assignment_path(card), as: :json

    assert_response :no_content
    assert card.reload.assigned_to?(users(:kevin))

    put card_resolution_record_path(card), params: {
      card_resolution_record: {
        root_cause: "Quote totals were recalculated from stale discount inputs.",
        fix_summary: "Normalized the discount inputs before recalculating totals.",
        verification_steps: "Opened the quote, refreshed the page, and confirmed the subtotal stayed unchanged.",
        linked_commit_shas: [ "abc123" ]
      }
    }, as: :json

    assert_response :success
    assert card.resolution_record.reload.gate_two_complete?
    assert card.resolution_record.code_evidence_present?
    assert_equal "needs_review", card.reload.cactus_workflow_state

    assert_difference -> { TrainingExample.count }, +1 do
      post card_resolution_path(card), as: :json
    end

    assert_response :created
    card.reload
    training_example = card.training_examples.order(:created_at).last

    assert card.closed?
    assert_equal "resolved", card.cactus_workflow_state
    assert training_example.pending_review?
    assert_equal training_example.id, @response.parsed_body["training_example_id"]

    post approve_training_example_path(training_example), params: {
      review_notes: "Good end-to-end training example."
    }

    assert_redirected_to training_example_path(training_example)
    assert training_example.reload.approved?
    assert_equal users(:kevin), training_example.reviewed_by
    assert_equal "closed", card.reload.cactus_workflow_state

    assert_difference -> { TrainingExampleExport.count }, +1 do
      get export_training_examples_path
    end

    assert_response :success
    assert_includes response.headers["Content-Disposition"], ".jsonl"

    payload = JSON.parse(response.body.lines.first)
    export = TrainingExampleExport.latest_first.first

    assert_equal training_example.id, payload.dig("metadata", "training_example_id")
    assert_equal card.id, payload.dig("metadata", "card_id")
    assert_equal export.completed_at.iso8601, payload.dig("metadata", "exported_at")
    assert training_example.reload.exported?
    assert_equal export, training_example.training_example_export
  end
end
