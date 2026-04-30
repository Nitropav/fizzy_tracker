require "test_helper"

class TrainingExamplesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @training_example = create_training_example
  end

  test "index is visible to admins" do
    get training_examples_path

    assert_response :success
    assert_match "Training Examples", response.body
    assert_match "The logo", response.body
  end

  test "index can filter by status" do
    @training_example.approve!(reviewer: users(:kevin))

    get training_examples_path(status: "approved")

    assert_response :success
    assert_match "The logo", response.body
  end

  test "show is visible to admins" do
    get training_example_path(@training_example)

    assert_response :success
    assert_match "Problem", response.body
    assert_match "Input context snapshot", response.body
  end

  test "approve" do
    post approve_training_example_path(@training_example), params: { review_notes: "Good example" }

    assert_redirected_to @training_example
    assert @training_example.reload.approved?
    assert_equal users(:kevin), @training_example.reviewed_by
    assert_equal "Good example", @training_example.review_notes
  end

  test "reject" do
    post reject_training_example_path(@training_example), params: { review_notes: "Too vague" }

    assert_redirected_to @training_example
    assert @training_example.reload.rejected?
    assert_equal "Too vague", @training_example.review_notes
  end

  test "export approved examples as jsonl" do
    @training_example.approve!(reviewer: users(:kevin), notes: "Good example")

    get export_training_examples_path

    assert_response :success
    assert_includes response.headers["Content-Disposition"], ".jsonl"

    line = response.body.lines.first
    payload = JSON.parse(line)
    assert_equal "system", payload.dig("messages", 0, "role")
    assert_equal "user", payload.dig("messages", 1, "role")
    assert_equal "assistant", payload.dig("messages", 2, "role")
    assert_equal @training_example.id, payload.dig("metadata", "training_example_id")
    assert @training_example.reload.exported?
  end

  test "non admins cannot access index" do
    logout_and_sign_in_as :david

    get training_examples_path

    assert_response :forbidden
  end

  test "cannot access another account training example" do
    other_account_example = TrainingExample.create!(
      account: accounts(:initech),
      card: cards(:radio),
      status: :pending_review,
      input_context: { "card" => { "id" => cards(:radio).id } },
      metadata: { "domain" => "other" }
    )

    get training_example_path(other_account_example)

    assert_response :not_found
  end

  private
    def create_training_example
      card = cards(:logo)
      card.create_resolution_record!(
        problem_description: "Logo is unreadable",
        reproduction_steps: "Open the card",
        expected_behavior: "Logo should be readable",
        actual_behavior: "Logo is too small",
        environment_context: "Fizzy card page",
        root_cause: "Image sizing used the wrong max width",
        fix_summary: "Adjusted the card image layout",
        verification_steps: "Opened the card and confirmed the logo is readable",
        domain: "ui",
        category: "bug",
        severity: "cosmetic"
      )

      TrainingExamples::Generator.new(card).generate
    end
end
