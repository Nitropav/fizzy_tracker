require "test_helper"

class Sessions::DevelopmentLoginsControllerTest < ActionDispatch::IntegrationTest
  test "create signs in fixture identity in local environments" do
    untenanted do
      post session_development_login_path(email_address: identities(:kevin).email_address)
    end

    assert_redirected_to landing_url(script_name: accounts("37s").slug)
    assert cookies.get_cookie("session_token").present?
  end

  test "new session page hides development login options by default" do
    cookies.delete(:session_token)

    untenanted do
      get new_session_path
    end

    assert_response :success
    assert_select "strong", text: "Development login", count: 0
    assert_select "form[action*=?]", session_development_login_path(script_name: nil), count: 0
  end

  test "new session page can show development login options when explicitly enabled" do
    previous_value = ENV["ENABLE_DEVELOPMENT_LOGIN"]
    ENV["ENABLE_DEVELOPMENT_LOGIN"] = "true"
    cookies.delete(:session_token)

    untenanted do
      get new_session_path
    end

    assert_response :success
    assert_select "strong", text: "Development login"
    assert_select "form[action*=?]", session_development_login_path(script_name: nil)
  ensure
    ENV["ENABLE_DEVELOPMENT_LOGIN"] = previous_value
  end
end
