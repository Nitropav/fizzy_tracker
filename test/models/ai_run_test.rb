require "test_helper"

class AiRunTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:logo)
  end

  test "defaults account from card" do
    ai_run = @card.ai_runs.create!(
      user: users(:david),
      run_type: "card_quality_review",
      input_context: { "card" => { "id" => @card.id } },
      output: {},
      metadata: {}
    )

    assert_equal @card.account, ai_run.account
    assert ai_run.pending?
  end

  test "complete lifecycle" do
    ai_run = @card.ai_runs.create!(
      user: users(:david),
      run_type: "card_quality_review",
      input_context: {},
      output: {},
      metadata: {}
    )

    ai_run.complete!(output: { "status" => "ready" }, metadata: { "reviewer_type" => "deterministic" })

    assert ai_run.completed?
    assert_equal "ready", ai_run.output["status"]
    assert_equal "deterministic", ai_run.metadata["reviewer_type"]
    assert ai_run.completed_at.present?
  end

  test "suggestion dismissal and applied lifecycle" do
    ai_run = @card.ai_runs.create!(
      user: users(:david),
      run_type: "issue_structuring",
      input_context: {},
      output: {},
      metadata: {}
    )
    ai_run.complete!(output: { "status" => "suggested" }, metadata: { "completed_by" => "deterministic" })

    assert ai_run.active_suggestion?

    ai_run.dismiss!(user: users(:david), reason: "not useful")

    assert ai_run.dismissed?
    assert_not ai_run.active_suggestion?
    assert_equal users(:david).id, ai_run.metadata["dismissed_by_id"]
    assert_equal "not useful", ai_run.metadata["dismissed_reason"]

    ai_run = @card.ai_runs.create!(
      user: users(:david),
      run_type: "resolution_draft",
      input_context: {},
      output: {},
      metadata: {}
    )
    ai_run.complete!(output: { "status" => "suggested" }, metadata: { "completed_by" => "deterministic" })
    ai_run.mark_applied!(user: users(:david))

    assert ai_run.applied?
    assert_not ai_run.active_suggestion?
    assert_equal users(:david).id, ai_run.metadata["applied_by_id"]
  end

  test "requires card to match account" do
    ai_run = AiRun.new(
      account: accounts(:initech),
      card: @card,
      run_type: "card_quality_review",
      input_context: {},
      output: {},
      metadata: {}
    )

    assert_not ai_run.valid?
    assert_includes ai_run.errors[:card], "must belong to the AI run account"
  end
end
