require "test_helper"

class Sessions::PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  STRONG_PASSWORD = "correct horse battery staple"

  test "new" do
    untenanted do
      get new_session_password_reset_path
    end

    assert_response :success
  end

  test "create sends reset instructions for existing identity" do
    identity = identities(:kevin)

    untenanted do
      assert_enqueued_email_with PasswordMailer, :reset, args: [ identity ] do
        post session_password_reset_path, params: { email_address: identity.email_address }
      end
    end

    assert_redirected_to new_session_path(script_name: nil)
  end

  test "create does not reveal unknown email addresses" do
    untenanted do
      assert_no_enqueued_emails do
        post session_password_reset_path, params: { email_address: "missing@example.com" }
      end
    end

    assert_redirected_to new_session_path(script_name: nil)
  end

  test "edit with valid token" do
    token = identities(:kevin).signed_id(purpose: :password_reset, expires_in: 30.minutes)

    untenanted do
      get edit_session_password_reset_path(token: token)
    end

    assert_response :success
  end

  test "edit with invalid token redirects to new reset request" do
    untenanted do
      get edit_session_password_reset_path(token: "invalid")
    end

    assert_redirected_to new_session_password_reset_path(script_name: nil)
  end

  test "update changes password and signs in" do
    identity = identities(:kevin)
    old_session = identity.sessions.create!
    token = identity.signed_id(purpose: :password_reset, expires_in: 30.minutes)

    untenanted do
      patch session_password_reset_path, params: {
        token: token,
        password: STRONG_PASSWORD,
        password_confirmation: STRONG_PASSWORD
      }
    end

    assert_redirected_to landing_path(script_name: nil)
    assert identity.reload.authenticate(STRONG_PASSWORD)
    assert_not Session.exists?(old_session.id), "Existing sessions should be invalidated when password changes"
    assert cookies.get_cookie("session_token").present?
  end

  test "update rejects short passwords" do
    identity = identities(:kevin)
    token = identity.signed_id(purpose: :password_reset, expires_in: 30.minutes)

    untenanted do
      patch session_password_reset_path, params: {
        token: token,
        password: "short",
        password_confirmation: "short"
      }
    end

    assert_response :unprocessable_entity
    assert_match "Password is too short", response.body
    assert identity.reload.authenticate("password")
  end

  test "update rejects password confirmation mismatch" do
    identity = identities(:kevin)
    token = identity.signed_id(purpose: :password_reset, expires_in: 30.minutes)

    untenanted do
      patch session_password_reset_path, params: {
        token: token,
        password: STRONG_PASSWORD,
        password_confirmation: "different strong password"
      }
    end

    assert_response :unprocessable_entity
    assert_match "Password confirmation", response.body
    assert identity.reload.authenticate("password")
  end

  test "update rejects blank password" do
    identity = identities(:kevin)
    token = identity.signed_id(purpose: :password_reset, expires_in: 30.minutes)

    untenanted do
      patch session_password_reset_path, params: {
        token: token,
        password: "",
        password_confirmation: ""
      }
    end

    assert_response :unprocessable_entity
    assert_match "blank", response.body
    assert identity.reload.authenticate("password")
  end
end
