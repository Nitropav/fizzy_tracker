require "test_helper"

class Cards::AiReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)

    assert_difference -> { card.ai_runs.count }, +1 do
      post card_ai_review_path(card)
    end

    assert_redirected_to card
    assert card.ai_runs.last.completed?
  end

  test "create as json" do
    card = cards(:logo)

    post card_ai_review_path(card), as: :json

    assert_response :created
    assert_equal "needs_work", @response.parsed_body["status"]
  end
end
