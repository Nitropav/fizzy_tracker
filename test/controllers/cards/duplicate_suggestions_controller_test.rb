require "test_helper"

class Cards::DuplicateSuggestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @card = cards(:logo)
  end

  test "create generates duplicate suggestion run" do
    assert_difference -> { @card.ai_runs.duplicate_issue_suggestions.count }, +1 do
      post card_duplicate_suggestion_path(@card)
    end

    assert_redirected_to card_path(@card, anchor: ActionView::RecordIdentifier.dom_id(@card, :resolution_record))
    assert_equal "Duplicate issue check completed.", flash[:notice]
    assert @card.ai_runs.duplicate_issue_suggestions.latest_first.first.completed?
  end

  test "reporter cannot create duplicate suggestion" do
    users(:david).update!(cactus_role: :reporter)
    logout_and_sign_in_as :david

    assert_no_difference -> { AiRun.count } do
      post card_duplicate_suggestion_path(@card)
    end

    assert_response :forbidden
  end
end
