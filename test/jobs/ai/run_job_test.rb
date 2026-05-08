require "test_helper"

class Ai::RunJobTest < ActiveJob::TestCase
  setup do
    Current.account = accounts(:"37s")
    Current.user = users(:kevin)
    @card = cards(:logo)
  end

  test "completes queued AI run inside account and user context" do
    ai_run = Ai::RunScheduler.enqueue!(
      card: @card,
      user: users(:kevin),
      run_type: "issue_structuring"
    )

    assert_predicate ai_run, :pending?
    assert_equal "web", ai_run.metadata["queued_by"]

    perform_enqueued_jobs

    ai_run.reload
    assert_predicate ai_run, :completed?
    assert_equal "suggested", ai_run.output["status"]
    assert_equal "deterministic", ai_run.metadata["completed_by"]
    assert_equal "web", ai_run.metadata["queued_by"]
  end

  test "does not rerun completed AI runs" do
    ai_run = Ai::IssueStructuringService.new(@card, user: users(:kevin)).suggest
    completed_at = ai_run.completed_at

    Ai::RunJob.perform_now(ai_run)

    assert_equal completed_at.to_i, ai_run.reload.completed_at.to_i
  end
end
