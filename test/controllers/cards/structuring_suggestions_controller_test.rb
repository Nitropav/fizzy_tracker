require "test_helper"

class Cards::StructuringSuggestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @card = cards(:logo)
  end

  test "create generates issue structuring suggestion" do
    assert_enqueued_with(job: Ai::RunJob) do
      assert_difference -> { @card.ai_runs.issue_structurings.count }, +1 do
        post card_structuring_suggestion_path(@card)
      end
    end

    assert_redirected_to card_path(@card, anchor: ActionView::RecordIdentifier.dom_id(@card, :resolution_record))
    assert_equal "Issue structuring suggestion queued.", flash[:notice]
    assert @card.ai_runs.issue_structurings.latest_first.first.pending?
  end

  test "queued issue structuring suggestion completes in background job" do
    perform_enqueued_jobs do
      post card_structuring_suggestion_path(@card)
    end

    ai_run = @card.ai_runs.issue_structurings.latest_first.first
    assert ai_run.completed?
    assert_equal "suggested", ai_run.output["status"]
  end

  test "apply fills only blank fields from suggestion" do
    record = @card.create_resolution_record!(problem_description: "Do not overwrite this")
    ai_run = Ai::IssueStructuringService.new(@card, user: users(:kevin)).suggest

    post apply_card_structuring_suggestion_path(@card, ai_run_id: ai_run.id)

    assert_redirected_to card_path(@card, anchor: ActionView::RecordIdentifier.dom_id(@card, :resolution_record))
    assert_equal "Applied 9 suggested fields.", flash[:notice]

    record.reload
    assert_equal "Do not overwrite this", record.problem_description
    assert_equal "Open the affected ES Windows workflow and follow the reporter's path until the issue appears.", record.reproduction_steps
    assert_equal "bug", record.category
    assert_equal "normal", record.priority
    assert ai_run.reload.applied?
    assert_not ai_run.active_suggestion?
  end

  test "apply respects reporter permissions and does not save classification fields" do
    users(:david).update!(cactus_role: :reporter)
    logout_and_sign_in_as :david

    record = @card.create_resolution_record!
    ai_run = Ai::IssueStructuringService.new(@card, user: users(:kevin)).suggest

    post apply_card_structuring_suggestion_path(@card, ai_run_id: ai_run.id)

    assert_redirected_to card_path(@card, anchor: ActionView::RecordIdentifier.dom_id(@card, :resolution_record))

    record.reload
    assert record.problem_description.present?
    assert_nil record.category
    assert_nil record.priority
  end

  test "apply cannot use another card suggestion" do
    other_card = cards(:text)
    ai_run = Ai::IssueStructuringService.new(other_card, user: users(:kevin)).suggest

    post apply_card_structuring_suggestion_path(@card, ai_run_id: ai_run.id)

    assert_response :not_found
  end

  test "apply cannot use dismissed suggestion" do
    ai_run = Ai::IssueStructuringService.new(@card, user: users(:kevin)).suggest
    ai_run.dismiss!(user: users(:kevin))

    post apply_card_structuring_suggestion_path(@card, ai_run_id: ai_run.id)

    assert_response :not_found
  end

  test "create cannot target inaccessible account card" do
    other_account_card = create_other_account_card

    assert_no_difference -> { AiRun.count } do
      post card_structuring_suggestion_path(other_account_card)
    end

    assert_response :not_found
  end

  private
    def create_other_account_card
      Current.with(account: accounts(:initech), session: sessions(:mike)) do
        boards(:miltons_wish_list).cards.create!(
          account: accounts(:initech),
          creator: users(:mike),
          status: :published,
          number: 999,
          title: "Other account card"
        )
      end
    end
end
