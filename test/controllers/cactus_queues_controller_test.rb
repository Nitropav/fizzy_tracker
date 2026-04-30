require "test_helper"

class CactusQueuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get cactus_queues_path

    assert_response :success
    assert_match "Cactus Queue", response.body
    assert_match "The logo", response.body
  end

  test "index filters by workflow state" do
    get cactus_queues_path(state: "needs_info")

    assert_response :success
    assert_match "Needs info", response.body
  end

  test "users only see accessible cards" do
    logout_and_sign_in_as :mike
    integration_session.default_url_options[:script_name] = accounts(:initech).slug

    get cactus_queues_path

    assert_response :success
    assert_match "I want to play my radio", response.body
    assert_no_match "The logo", response.body
  end
end
