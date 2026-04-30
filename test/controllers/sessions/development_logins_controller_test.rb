require "test_helper"

class Sessions::DevelopmentLoginsControllerTest < ActionDispatch::IntegrationTest
  test "create signs in fixture identity in local environments" do
    untenanted do
      post session_development_login_path(email_address: identities(:kevin).email_address)
    end

    assert_redirected_to landing_path(script_name: nil)
    assert cookies.get_cookie("session_token").present?
  end

  test "new session page shows development login options in local environments" do
    cookies.delete(:session_token)

    untenanted do
      get new_session_path
    end

    assert_response :success
    assert_select "strong", text: "Development login"
    assert_select "form[action*=?]", session_development_login_path(script_name: nil)
  end
end
