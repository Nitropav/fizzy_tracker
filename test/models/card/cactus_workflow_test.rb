require "test_helper"

class Card::CactusWorkflowTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "draft card is draft" do
    assert_equal "draft", cards(:unfinished_thoughts).cactus_workflow_state
  end

  test "published card without structured gate one is needs info" do
    assert_equal "needs_info", cards(:logo).cactus_workflow_state
  end

  test "gate one complete card awaiting triage is open" do
    card = cards(:buy_domain)
    card.create_resolution_record!(gate_one_attrs)

    assert_equal "open", card.cactus_workflow_state
  end

  test "triaged card with incomplete gate two is in progress" do
    card = cards(:text)
    card.create_resolution_record!(gate_one_attrs)

    assert_equal "in_progress", card.cactus_workflow_state
  end

  test "triaged card with complete gate two is needs review" do
    card = cards(:text)
    card.create_resolution_record!(gate_one_attrs.merge(gate_two_attrs))

    assert_equal "needs_review", card.cactus_workflow_state
  end

  test "closed card without approved training example is resolved" do
    card = cards(:logo)
    card.create_resolution_record!(gate_one_attrs.merge(gate_two_attrs))
    card.close

    assert_equal "resolved", card.reload.cactus_workflow_state
  end

  test "closed card with approved training example is closed" do
    card = cards(:logo)
    card.create_resolution_record!(gate_one_attrs.merge(gate_two_attrs))
    card.close
    card.training_examples.last.approve!(reviewer: users(:david))

    assert_equal "closed", card.reload.cactus_workflow_state
  end

  private
    def gate_one_attrs
      {
        problem_description: "Logo is unreadable",
        reproduction_steps: "Open the card",
        expected_behavior: "Logo should be readable",
        actual_behavior: "Logo is too small",
        environment_context: "Fizzy card page"
      }
    end

    def gate_two_attrs
      {
      root_cause: "Image sizing used the wrong max width",
      fix_summary: "Adjusted the card image layout",
      verification_steps: "Opened the card and confirmed the logo is readable",
      linked_commit_shas: [ "abc123" ]
      }
    end
end
