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

  test "create cannot review inaccessible account card" do
    other_account_card = create_other_account_card

    assert_no_difference -> { AiRun.count } do
      post card_ai_review_path(other_account_card), as: :json
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
