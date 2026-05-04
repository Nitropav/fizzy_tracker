require "test_helper"

class TrainingExampleExportTest < ActiveSupport::TestCase
  setup do
    @training_example = create_training_example
    @training_example.approve!(reviewer: users(:kevin))
  end

  test "belongs to an account user and ordered example ids" do
    training_example_export = accounts(:"37s").training_example_exports.create!(
      user: users(:kevin),
      filename: "training-examples.jsonl",
      example_count: 1,
      training_example_ids: [ @training_example.id ],
      completed_at: Time.current
    )

    assert_equal users(:kevin), training_example_export.user
    assert_equal [ @training_example ], training_example_export.training_examples
  end

  test "requires user to belong to export account" do
    training_example_export = accounts(:"37s").training_example_exports.build(
      user: users(:mike),
      filename: "training-examples.jsonl",
      example_count: 0,
      completed_at: Time.current
    )

    assert_not training_example_export.valid?
    assert_includes training_example_export.errors[:user], "must belong to the export account"
  end

  private
    def create_training_example
      card = cards(:logo)
      card.training_examples.create!(
        status: :pending_review,
        input_context: { "card" => { "id" => card.id } },
        problem_summary: "Logo is unreadable",
        root_cause: "Image max width was wrong",
        resolution_summary: "Adjusted image layout",
        verification_steps: "Opened the card and verified the logo",
        metadata: { "card_id" => card.id, "domain" => "ui" }
      )
    end
end
