require "test_helper"

class Cards::AiReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)

    assert_enqueued_with(job: Ai::RunJob) do
      assert_difference -> { card.ai_runs.count }, +1 do
        post card_ai_review_path(card)
      end
    end

    assert_redirected_to card
    assert_equal "Training quality review queued.", flash[:notice]
    assert card.ai_runs.last.pending?
  end

  test "queued review completes in background job" do
    card = cards(:logo)

    perform_enqueued_jobs do
      post card_ai_review_path(card)
    end

    assert card.ai_runs.last.completed?
    assert_equal "needs_work", card.ai_runs.last.output["status"]
  end

  test "create as json" do
    card = cards(:logo)

    post card_ai_review_path(card), as: :json

    assert_response :accepted
    assert_equal "pending", @response.parsed_body["status"]
    assert_equal "card_quality_review", @response.parsed_body["run_type"]
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
