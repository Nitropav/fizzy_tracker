require "test_helper"

class Cards::SelfAssignmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create assigns to current user" do
    card = cards(:layout)

    assert_not card.assigned_to?(users(:kevin))

    post card_self_assignment_path(card), as: :turbo_stream
    assert_response :success
    assert_meta_replaced(card)
    assert card.reload.assigned_to?(users(:kevin))
  end

  test "create toggles off when already assigned" do
    card = cards(:logo)

    assert card.assigned_to?(users(:kevin))

    post card_self_assignment_path(card), as: :turbo_stream
    assert_response :success
    assert_meta_replaced(card)
    assert_not card.reload.assigned_to?(users(:kevin))
  end

  test "create as JSON" do
    card = cards(:layout)

    assert_not card.assigned_to?(users(:kevin))

    post card_self_assignment_path(card), as: :json
    assert_response :no_content
    assert card.reload.assigned_to?(users(:kevin))
  end

  test "support users cannot claim developer work" do
    logout_and_sign_in_as :jz
    card = cards(:layout)

    assert_no_changes -> { card.reload.assigned_to?(users(:jz)) } do
      post card_self_assignment_path(card), as: :json
    end

    assert_response :forbidden
  end

  test "create as HTML redirects back" do
    card = cards(:layout)

    assert_not card.assigned_to?(users(:kevin))

    post card_self_assignment_path(card)
    assert_redirected_to card_path(card)
    assert card.reload.assigned_to?(users(:kevin))
  end

  test "create as HTML can redirect back to cactus queue" do
    card = cards(:text)

    assert_not card.assigned_to?(users(:kevin))

    post card_self_assignment_path(card), params: {
      return_to: "cactus_queue",
      queue_state: "in_progress"
    }

    assert_redirected_to cactus_queues_path(state: "in_progress")
    assert card.reload.assigned_to?(users(:kevin))
  end

  private
    def assert_meta_replaced(card)
      assert_turbo_stream action: :replace, target: dom_id(card, :meta)
    end
end
