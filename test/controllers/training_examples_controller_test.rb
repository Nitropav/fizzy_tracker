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
    assert_match "High", response.body
    assert_match "Export history", response.body
  end

  test "index is visible to cactus reviewers" do
    users(:david).update!(cactus_role: :reviewer)
    logout_and_sign_in_as :david

    get training_examples_path

    assert_response :success
    assert_match "Training Examples", response.body
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
    assert_match "Issue overview", response.body
    assert_match "Gate 1 - Reporter side", response.body
    assert_match "Problem description", response.body
    assert_match "Logo is unreadable", response.body
    assert_match "Reproduction steps", response.body
    assert_match "Expected behavior", response.body
    assert_match "Actual behavior", response.body
    assert_match "Environment", response.body
    assert_match "Gate 2 - Developer side", response.body
    assert_match "Root cause", response.body
    assert_match "Image sizing used the wrong max width", response.body
    assert_match "Fix summary", response.body
    assert_match "Verification steps", response.body
    assert_match "Code evidence", response.body
    assert_match "Training metadata", response.body
    assert_match "No automatic GitHub code evidence linked", response.body
    assert_match "JSONL preview", response.body
    assert_match "Input context snapshot", response.body
    assert_select "input[type='submit'][value='Approve with notes']"
    assert_select "input[type='submit'][value='Reject with notes']"
  end

  test "show hides review actions after approval" do
    @training_example.approve!(reviewer: users(:kevin), notes: "Good example")

    get training_example_path(@training_example)

    assert_response :success
    assert_match "Good example", response.body
    assert_select "form[action=?]", approve_training_example_path(@training_example), count: 0
    assert_select "input[type='submit'][value='Approve with notes']", count: 0
    assert_select "input[type='submit'][value='Reject with notes']", count: 0
  end

  test "approve" do
    post approve_training_example_path(@training_example), params: { review_notes: "Good example" }

    assert_redirected_to @training_example
    assert @training_example.reload.approved?
    assert_equal users(:kevin), @training_example.reviewed_by
    assert_equal "Good example", @training_example.review_notes
  end

  test "approve is blocked after export" do
    @training_example.approve!(reviewer: users(:kevin), notes: "Good example")
    @training_example.mark_exported!

    post reject_training_example_path(@training_example), params: { review_notes: "Changed my mind" }

    assert_redirected_to @training_example
    assert_equal "Training example has already left review.", flash[:alert]
    assert @training_example.reload.exported?
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

    assert_difference -> { TrainingExampleExport.count }, +1 do
      get export_training_examples_path
    end

    assert_response :success
    assert_includes response.headers["Content-Disposition"], ".jsonl"

    training_example_export = TrainingExampleExport.latest_first.first
    assert_equal users(:kevin), training_example_export.user
    assert_equal [ @training_example.id ], training_example_export.training_example_ids

    line = response.body.lines.first
    payload = JSON.parse(line)
    assert_equal "system", payload.dig("messages", 0, "role")
    assert_equal "user", payload.dig("messages", 1, "role")
    assert_equal "assistant", payload.dig("messages", 2, "role")
    assert_equal @training_example.id, payload.dig("metadata", "training_example_id")
    assert_equal training_example_export.completed_at.iso8601, payload.dig("metadata", "exported_at")
    assert @training_example.reload.exported?
    assert_equal training_example_export, @training_example.training_example_export
  end

  test "export only includes current account approved examples" do
    @training_example.approve!(reviewer: users(:kevin), notes: "Good example")
    other_account_example = create_other_account_training_example
    other_account_example.approve!(reviewer: users(:mike), notes: "Other account example")

    get export_training_examples_path

    assert_response :success
    exported_ids = response.body.lines.map { JSON.parse(it).dig("metadata", "training_example_id") }
    assert_equal [ @training_example.id ], exported_ids
    assert @training_example.reload.exported?
    assert other_account_example.reload.approved?
  end

  test "export redirects when no examples are approved" do
    assert_no_difference -> { TrainingExampleExport.count } do
      get export_training_examples_path
    end

    assert_redirected_to training_examples_path
    assert_equal "No approved training examples are ready for export.", flash[:alert]
  end

  test "non admins cannot access index" do
    logout_and_sign_in_as :david

    get training_examples_path

    assert_response :forbidden
  end

  test "non admins cannot export examples" do
    logout_and_sign_in_as :david

    get export_training_examples_path

    assert_response :forbidden
  end

  test "cannot access another account training example" do
    other_account_example = create_other_account_training_example

    get training_example_path(other_account_example)

    assert_response :not_found
  end

  test "cannot approve another account training example" do
    other_account_example = create_other_account_training_example

    post approve_training_example_path(other_account_example), params: { review_notes: "Should not work" }

    assert_response :not_found
    assert other_account_example.reload.pending_review?
  end

  test "cannot reject another account training example" do
    other_account_example = create_other_account_training_example

    post reject_training_example_path(other_account_example), params: { review_notes: "Should not work" }

    assert_response :not_found
    assert other_account_example.reload.pending_review?
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
        priority: "high",
        domain: "ui",
        category: "bug",
        severity: "cosmetic"
      )

      TrainingExamples::Generator.new(card).generate
    end

    def create_other_account_training_example
      TrainingExample.create!(
        account: accounts(:initech),
        card: cards(:radio),
        status: :pending_review,
        input_context: { "card" => { "id" => cards(:radio).id } },
        metadata: { "domain" => "other" }
      )
    end
end
