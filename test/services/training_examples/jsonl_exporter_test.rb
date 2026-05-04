require "test_helper"

class TrainingExamples::JsonlExporterTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:logo)
    @training_example = @card.training_examples.create!(
      status: :approved,
      input_context: {
        "card" => { "id" => @card.id },
        "resolution_record" => { "gate_one_complete" => true, "gate_two_complete" => true }
      },
      problem_summary: "Logo is unreadable",
      root_cause: "Image max width was wrong",
      resolution_summary: "Adjusted image layout",
      verification_steps: "Opened the card and verified the logo",
      metadata: {
        "card_id" => @card.id,
        "domain" => "ui",
        "commit_shas" => [ "abc123" ]
      },
      reviewed_by: users(:david),
      reviewed_at: Time.current
    )
  end

  test "exports one json object per line" do
    jsonl = TrainingExamples::JsonlExporter.new([ @training_example ]).to_jsonl

    assert_equal 1, jsonl.lines.size

    payload = JSON.parse(jsonl.lines.first)
    assert_equal %w[ system user assistant ], payload["messages"].map { |message| message["role"] }
    assert_includes payload.dig("messages", 1, "content"), "Logo is unreadable"
    assert_includes payload.dig("messages", 2, "content"), "Adjusted image layout"
    assert_equal @training_example.id, payload.dig("metadata", "training_example_id")
    assert_equal [ "abc123" ], payload.dig("metadata", "commit_shas")
    assert_nil payload.dig("metadata", "exported_at")
  end

  test "can include a stable exported timestamp" do
    exported_at = Time.current.change(usec: 0)
    jsonl = TrainingExamples::JsonlExporter.new([ @training_example ], exported_at: exported_at).to_jsonl

    payload = JSON.parse(jsonl.lines.first)
    assert_equal exported_at.iso8601, payload.dig("metadata", "exported_at")
  end

  test "exports empty string when no examples are provided" do
    assert_equal "", TrainingExamples::JsonlExporter.new([]).to_jsonl
  end
end
