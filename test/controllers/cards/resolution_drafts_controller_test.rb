require "test_helper"

class Cards::ResolutionDraftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @card = cards(:logo)
  end

  test "create generates resolution draft and redirects back to Gate 2 page" do
    assert_difference -> { @card.ai_runs.resolution_drafts.count }, +1 do
      post card_resolution_draft_path(@card), params: { return_to: "gate_two" }
    end

    assert_redirected_to edit_card_resolution_record_path(@card)
    assert_equal "Resolution draft generated.", flash[:notice]
    assert @card.ai_runs.resolution_drafts.latest_first.first.completed?
  end

  test "apply fills only blank Gate 2 fields from draft" do
    record = @card.create_resolution_record!(root_cause: "Do not overwrite this")
    ai_run = Ai::ResolutionDraftService.new(@card, user: users(:kevin)).suggest

    post apply_card_resolution_draft_path(@card), params: { ai_run_id: ai_run.id }

    assert_redirected_to card_path(@card, anchor: ActionView::RecordIdentifier.dom_id(@card, :resolution_record))
    assert_match "Applied", flash[:notice]

    record.reload
    assert_equal "Do not overwrite this", record.root_cause
    assert record.fix_summary.present?
    assert record.verification_steps.present?
    assert ai_run.reload.applied?
    assert_not ai_run.active_suggestion?
  end

  test "reporter cannot create resolution draft" do
    users(:david).update!(cactus_role: :reporter)
    logout_and_sign_in_as :david

    assert_no_difference -> { AiRun.count } do
      post card_resolution_draft_path(@card)
    end

    assert_response :forbidden
  end

  test "apply cannot use another card draft" do
    other_card = cards(:text)
    ai_run = Ai::ResolutionDraftService.new(other_card, user: users(:kevin)).suggest

    post apply_card_resolution_draft_path(@card), params: { ai_run_id: ai_run.id }

    assert_response :not_found
  end

  test "apply cannot use dismissed draft" do
    ai_run = Ai::ResolutionDraftService.new(@card, user: users(:kevin)).suggest
    ai_run.dismiss!(user: users(:kevin))

    post apply_card_resolution_draft_path(@card), params: { ai_run_id: ai_run.id }

    assert_response :not_found
  end
end
