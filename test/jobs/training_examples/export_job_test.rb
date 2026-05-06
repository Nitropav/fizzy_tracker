require "test_helper"

class TrainingExamples::ExportJobTest < ActiveJob::TestCase
  setup do
    @training_example = create_training_example
    @training_example.approve!(reviewer: users(:kevin))
  end

  test "exports reserved approved examples" do
    export = TrainingExampleExport.queue_for!(account: accounts(:"37s"), user: users(:kevin))

    assert_predicate export, :pending?
    assert_equal export, @training_example.reload.training_example_export

    TrainingExamples::ExportJob.perform_now(export)

    assert_predicate export.reload, :completed?
    assert_predicate export.file, :attached?
    assert_equal 1, export.example_count
    assert @training_example.reload.exported?

    payload = JSON.parse(export.file.download.lines.first)
    assert_equal @training_example.id, payload.dig("metadata", "training_example_id")
    assert_equal export.completed_at.iso8601, payload.dig("metadata", "exported_at")
  end

  test "failed export releases reserved approved examples" do
    export = TrainingExampleExport.queue_for!(account: accounts(:"37s"), user: users(:kevin))
    TrainingExamples::JsonlExporter.any_instance.stubs(:to_jsonl).raises(StandardError, "export failed")

    TrainingExamples::ExportJob.perform_now(export)

    assert_predicate export.reload, :failed?
    assert_match "export failed", export.error_message
    assert @training_example.reload.approved?
    assert_nil @training_example.training_example_export
  end

  private
    def create_training_example
      card = cards(:logo)
      card.training_examples.create!(
        status: :pending_review,
        input_context: {
          "card" => { "id" => card.id },
          "resolution_record" => { "gate_one_complete" => true, "gate_two_complete" => true }
        },
        problem_summary: "Logo is unreadable",
        root_cause: "Image max width was wrong",
        resolution_summary: "Adjusted image layout",
        verification_steps: "Opened the card and verified the logo",
        metadata: { "card_id" => card.id, "domain" => "ui" }
      )
    end
end
