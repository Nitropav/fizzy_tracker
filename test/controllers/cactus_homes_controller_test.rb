require "test_helper"

class CactusHomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get cactus_home_path

    assert_response :success
    assert_match "Cactus Bug Tracker", response.body
    assert_select "a[href=?]", cactus_queues_path, text: "Open queue"
    assert_select "a[href=?]", cactus_work_path, text: "View my work"
    assert_select "a[href=?]", boards_path, text: "View projects"
  end

  test "show links to focused new issue flow" do
    get cactus_home_path

    assert_response :success
    assert_select "a[href=?]", new_cactus_issue_path, text: "New issue"
  end

  test "admin sees training pipeline actions" do
    get cactus_home_path

    assert_response :success
    assert_match "Admin pipeline", response.body
    assert_select "a[href=?]", training_examples_path, text: "Review examples"
    assert_select "a[href=?]", cactus_dashboard_path, text: "Open dashboard"
    assert_select "a[href=?]", new_legacy_imports_asana_path, text: "Import tasks"
  end

  test "member does not see training pipeline actions" do
    logout_and_sign_in_as :david

    get cactus_home_path

    assert_response :success
    assert_no_match "Admin pipeline", response.body
    assert_select "a[href=?]", training_examples_path, count: 0
    assert_select "a[href=?]", cactus_dashboard_path, count: 0
    assert_select "a[href=?]", new_legacy_imports_asana_path, count: 0
  end
end
