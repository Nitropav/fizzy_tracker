require "test_helper"

class CactusDashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show is visible to admins" do
    get cactus_dashboard_path

    assert_response :success
    assert_match "Cactus Dashboard", response.body
    assert_match "Workflow", response.body
    assert_match "Gate Coverage", response.body
    assert_match "Training Corpus", response.body
    assert_match "Code Evidence", response.body
    assert_match "Legacy Imports", response.body
    assert_match "Operational alerts", response.body
    assert_match "Activity window", response.body
    assert_match "Activity Trends", response.body
    assert_match "Last 7 days", response.body
    assert_match "Backlog Health", response.body
    assert_match "Training Exports", response.body
    assert_match "GitHub Webhooks", response.body
    assert_match "AI Suggestion Types", response.body
    assert_select "a[href=?]", cactus_integrations_path, text: "Integrations"
  end

  test "show accepts activity period filter" do
    get cactus_dashboard_path(period: "7")

    assert_response :success
    assert_match "Last 7 days", response.body
    assert_select "a[aria-current=?]", "page", text: "Last 7 days"
  end

  test "non admins cannot access dashboard" do
    logout_and_sign_in_as :david

    get cactus_dashboard_path

    assert_response :forbidden
  end

  test "cactus reviewers can access dashboard" do
    users(:david).update!(cactus_role: :reviewer)
    logout_and_sign_in_as :david

    get cactus_dashboard_path

    assert_response :success
    assert_match "Cactus Dashboard", response.body
  end
end
