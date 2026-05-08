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

  test "root routes to cactus home" do
    get root_path

    assert_response :success
    assert_match "Cactus Bug Tracker", response.body
  end

  test "show links to focused new issue flow" do
    get cactus_home_path

    assert_response :success
    assert_select "a[href=?]", new_cactus_issue_path, text: "New issue"
  end

  test "admin sees operations pipeline actions" do
    get cactus_home_path

    assert_response :success
    assert_match "Operations pipeline", response.body
    assert_select "a[href=?]", training_examples_path, text: "Review examples"
    assert_select "a[href=?]", cactus_dashboard_path, text: "Open dashboard"
    assert_select "a[href=?]", new_legacy_imports_asana_path, text: "Import tasks"
    assert_select "a[href=?]", account_join_code_path, text: "Invite people"
    assert_select "a[href=?]", account_settings_path, text: "Manage users"
  end

  test "developer sees my work but not queue or operations pipeline" do
    logout_and_sign_in_as :david

    get cactus_home_path

    assert_response :success
    assert_select "a[href=?]", new_cactus_issue_path, text: "New issue"
    assert_select "a[href=?]", cactus_work_path, text: "View my work"
    assert_select "a[href=?]", cactus_queues_path, count: 0
    assert_no_match "Operations pipeline", response.body
    assert_select "a[href=?]", training_examples_path, count: 0
    assert_select "a[href=?]", cactus_dashboard_path, count: 0
    assert_select "a[href=?]", new_legacy_imports_asana_path, count: 0
    assert_select "a[href=?]", boards_path, text: "View projects", count: 0
    assert_select "a[href=?]", account_join_code_path, count: 0
    assert_select "a[href=?]", account_settings_path, count: 0
  end

  test "reporter only sees issue intake" do
    users(:david).update!(cactus_role: :reporter)
    logout_and_sign_in_as :david

    get cactus_home_path

    assert_response :success
    assert_select "a[href=?]", new_cactus_issue_path, text: "New issue"
    assert_select "a[href=?]", cactus_queues_path, count: 0
    assert_select "a[href=?]", cactus_work_path, count: 0
    assert_no_match "Operations pipeline", response.body
    assert_select "a[href=?]", training_examples_path, count: 0
    assert_select "a[href=?]", cactus_dashboard_path, count: 0
    assert_select "a[href=?]", new_legacy_imports_asana_path, count: 0
  end

  test "support sees queue and import without developer or review actions" do
    logout_and_sign_in_as :jz

    get cactus_home_path

    assert_response :success
    assert_select "a[href=?]", new_cactus_issue_path, text: "New issue"
    assert_select "a[href=?]", cactus_queues_path, text: "Open queue"
    assert_select "a[href=?]", new_legacy_imports_asana_path, text: "Import tasks"
    assert_select "a[href=?]", legacy_imports_asana_issues_path, text: "Review legacy"
    assert_select "a[href=?]", cactus_work_path, count: 0
    assert_select "a[href=?]", training_examples_path, count: 0
    assert_select "a[href=?]", cactus_dashboard_path, count: 0
    assert_select "a[href=?]", account_settings_path, count: 0
  end

  test "reviewer sees training review and dashboard only" do
    users(:david).update!(cactus_role: :reviewer)
    logout_and_sign_in_as :david

    get cactus_home_path

    assert_response :success
    assert_select "a[href=?]", new_cactus_issue_path, text: "New issue"
    assert_select "a[href=?]", training_examples_path, text: "Review examples"
    assert_select "a[href=?]", cactus_dashboard_path, text: "Open dashboard"
    assert_select "a[href=?]", cactus_queues_path, count: 0
    assert_select "a[href=?]", cactus_work_path, count: 0
    assert_select "a[href=?]", new_legacy_imports_asana_path, count: 0
    assert_select "a[href=?]", account_settings_path, count: 0
  end
end
