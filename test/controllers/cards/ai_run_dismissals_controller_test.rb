require "test_helper"

class Cards::AiRunDismissalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @card = cards(:logo)
  end

  test "dismisses issue structuring suggestion from card detail" do
    ai_run = Ai::IssueStructuringService.new(@card, user: users(:kevin)).suggest

    post card_ai_run_dismissal_path(@card, ai_run), params: { reason: "not useful" }

    assert_redirected_to card_path(@card, anchor: ActionView::RecordIdentifier.dom_id(@card, :resolution_record))
    assert_equal "AI suggestion dismissed.", flash[:notice]
    assert ai_run.reload.dismissed?
    assert_not ai_run.active_suggestion?
    assert_equal "not useful", ai_run.metadata["dismissed_reason"]
  end

  test "dismisses resolution draft back to Gate 2 page" do
    ai_run = Ai::ResolutionDraftService.new(@card, user: users(:kevin)).suggest

    post card_ai_run_dismissal_path(@card, ai_run), params: { return_to: "gate_two" }

    assert_redirected_to edit_card_resolution_record_path(@card)
    assert ai_run.reload.dismissed?
  end

  test "reporter can dismiss own issue structuring suggestion" do
    users(:david).update!(cactus_role: :reporter)
    logout_and_sign_in_as :david
    ai_run = Ai::IssueStructuringService.new(@card, user: users(:david)).suggest

    post card_ai_run_dismissal_path(@card, ai_run)

    assert_redirected_to card_path(@card, anchor: ActionView::RecordIdentifier.dom_id(@card, :resolution_record))
    assert ai_run.reload.dismissed?
  end

  test "reporter cannot dismiss internal duplicate suggestion" do
    ai_run = Ai::DuplicateIssueSuggestionService.new(@card, user: users(:kevin)).suggest
    users(:david).update!(cactus_role: :reporter)
    logout_and_sign_in_as :david

    post card_ai_run_dismissal_path(@card, ai_run)

    assert_response :forbidden
    assert_not ai_run.reload.dismissed?
  end

  test "cannot dismiss already applied suggestion" do
    ai_run = Ai::IssueStructuringService.new(@card, user: users(:kevin)).suggest
    ai_run.mark_applied!(user: users(:kevin))

    post card_ai_run_dismissal_path(@card, ai_run)

    assert_response :not_found
  end
end
