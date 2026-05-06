require "test_helper"

class TrainingExampleExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @training_example = create_training_example
    @training_example.approve!(reviewer: users(:kevin))
    @export = create_export(@training_example)
  end

  test "index is visible to reviewers" do
    get training_example_exports_path

    assert_response :success
    assert_match "Training Export History", response.body
    assert_match @export.filename, response.body
    assert_select "a[href=?]", training_example_export_path(@export), text: "Download"
  end

  test "show downloads export jsonl" do
    get training_example_export_path(@export)

    assert_response :success
    assert_includes response.headers["Content-Disposition"], @export.filename

    payload = JSON.parse(response.body.lines.first)
    assert_equal @training_example.id, payload.dig("metadata", "training_example_id")
    assert_equal @export.completed_at.iso8601, payload.dig("metadata", "exported_at")
  end

  test "non reviewers cannot access export history" do
    logout_and_sign_in_as :david

    get training_example_exports_path

    assert_response :forbidden
    assert_match "Access denied", response.body
  end

  test "cannot download another account export" do
    other_export = accounts(:initech).training_example_exports.create!(
      user: users(:mike),
      filename: "other.jsonl",
      example_count: 0,
      training_example_ids: [],
      completed_at: Time.current
    )

    get training_example_export_path(other_export)

    assert_response :not_found
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

    def create_export(training_example)
      accounts(:"37s").training_example_exports.create!(
      user: users(:kevin),
      status: :completed,
      filename: "training-examples-test.jsonl",
      example_count: 1,
      training_example_ids: [ training_example.id ],
        completed_at: Time.current
      )
    end
end
