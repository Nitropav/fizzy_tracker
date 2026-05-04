require "test_helper"

class Ai::IssueStructuringServiceTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:logo)
  end

  test "creates completed issue structuring run with gate one and classification suggestions" do
    @card.update!(title: "Wrong pricing blocks ordering", description: "Customer cannot order because pricing is wrong.")

    assert_difference -> { AiRun.count }, +1 do
      @ai_run = Ai::IssueStructuringService.new(@card, user: users(:david)).suggest
    end

    assert @ai_run.completed?
    assert_equal "issue_structuring", @ai_run.run_type
    assert_equal "suggested", @ai_run.output["status"]
    assert_equal "Customer cannot order because pricing is wrong.", @ai_run.output.dig("suggested_fields", "problem_description")
    assert_equal "urgent", @ai_run.output.dig("suggested_fields", "priority")
    assert_equal "bug", @ai_run.output.dig("suggested_fields", "category")
    assert_equal "pricing", @ai_run.output.dig("suggested_fields", "domain")
    assert_equal "blocks ordering", @ai_run.output.dig("suggested_fields", "severity")
    assert_equal "deterministic", @ai_run.metadata["completed_by"]
  end

  test "warns when issue description is empty" do
    @card.update!(description: "")

    ai_run = Ai::IssueStructuringService.new(@card, user: users(:david)).suggest

    assert_includes ai_run.output["warnings"], "Issue description is empty; suggestions are mostly based on the title."
  end
end
