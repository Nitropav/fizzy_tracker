require "test_helper"

class TrainingExamples::GeneratorTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:logo)
  end

  test "generates pending review example from complete resolution record" do
    @card.create_resolution_record!(resolution_record_attrs)
    @card.code_links.create!(
      provider: "github",
      external_type: "pull_request",
      external_id: "42",
      repository: "cactus/fizzy_tracker",
      sha: "def456",
      title: "Fix logo",
      url: "https://github.com/cactus/fizzy_tracker/pull/42",
      metadata: { "action" => "opened" }
    )

    assert_difference -> { TrainingExample.count }, +1 do
      @training_example = TrainingExamples::Generator.new(@card).generate
    end

    assert @training_example.pending_review?
    assert_equal @card.account, @training_example.account
    assert_equal "Logo is unreadable in the card detail view", @training_example.problem_summary
    assert_equal "Image sizing used the wrong max width", @training_example.root_cause
    assert_equal "Adjusted the card image layout", @training_example.resolution_summary
    assert_equal "ui", @training_example.metadata["domain"]
    assert_equal [ "abc123" ], @training_example.metadata["commit_shas"]
    assert_equal [ "https://github.com/cactus/fizzy_tracker/pull/42" ], @training_example.metadata["pr_urls"]
    assert_equal true, @training_example.metadata["code_evidence_present"]
    assert_equal "needs_review", @training_example.metadata["cactus_workflow_state"]
    assert_equal @card.id, @training_example.input_context.dig("card", "id")
  end

  test "updates existing draft or pending training example instead of duplicating" do
    @card.create_resolution_record!(resolution_record_attrs)
    existing = @card.training_examples.create!(
      status: :draft,
      input_context: { "stale" => true },
      metadata: { "stale" => true }
    )

    assert_no_difference -> { TrainingExample.count } do
      assert_equal existing, TrainingExamples::Generator.new(@card).generate
    end

    assert existing.reload.pending_review?
    assert_equal "Logo is unreadable in the card detail view", existing.problem_summary
  end

  test "does not overwrite approved training example" do
    @card.create_resolution_record!(resolution_record_attrs)
    approved = @card.training_examples.create!(
      status: :approved,
      input_context: { "approved" => true },
      metadata: { "approved" => true }
    )

    assert_difference -> { TrainingExample.count }, +1 do
      TrainingExamples::Generator.new(@card).generate
    end

    assert approved.reload.approved?
    assert_equal({ "approved" => true }, approved.input_context)
  end

  test "requires resolution record" do
    assert_raises TrainingExamples::Generator::MissingResolutionRecord do
      TrainingExamples::Generator.new(@card).generate
    end
  end

  test "requires complete gate one" do
    @card.create_resolution_record!(
      root_cause: "Cause",
      fix_summary: "Fix",
      verification_steps: "Verify"
    )

    assert_raises TrainingExamples::Generator::IncompleteGateOne do
      TrainingExamples::Generator.new(@card).generate
    end
  end

  test "requires complete gate two" do
    @card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page"
    )

    assert_raises TrainingExamples::Generator::IncompleteGateTwo do
      TrainingExamples::Generator.new(@card).generate
    end
  end

  private
    def resolution_record_attrs
      {
        problem_description: "Logo is unreadable",
        reproduction_steps: "Open the card",
        expected_behavior: "Logo should be readable",
        actual_behavior: "Logo is too small",
        environment_context: "Fizzy card page",
        structured_summary: "Logo is unreadable in the card detail view",
        category: "bug",
        domain: "ui",
        severity: "cosmetic",
        root_cause: "Image sizing used the wrong max width",
        fix_summary: "Adjusted the card image layout",
        verification_steps: "Opened the card and confirmed the logo is readable",
        linked_commit_shas: [ "abc123" ]
      }
    end
end
