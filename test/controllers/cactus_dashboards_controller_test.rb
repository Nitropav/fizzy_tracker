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
    assert_select "a[href=?]", cactus_integrations_path, text: "Integrations"
  end

  test "non admins cannot access dashboard" do
    logout_and_sign_in_as :david

    get cactus_dashboard_path

    assert_response :forbidden
  end
end
