require "test_helper"

class Users::PasswordsControllerTest < ActionDispatch::IntegrationTest
  STRONG_PASSWORD = "correct horse battery staple"

  setup do
    sign_in_as :kevin
  end

  test "admin resets member password and invalidates sessions" do
    assert identities(:david).authenticate("password")
    assert_difference -> { identities(:david).sessions.count }, -1 do
      patch user_password_path(users(:david)), params: {
        user: {
          password: STRONG_PASSWORD,
          password_confirmation: STRONG_PASSWORD
        }
      }
    end

    assert_redirected_to account_settings_path
    assert identities(:david).reload.authenticate(STRONG_PASSWORD)
  end

  test "admin cannot reset owner password" do
    assert_no_changes -> { identities(:jason).reload.password_digest } do
      patch user_password_path(users(:jason)), params: {
        user: {
          password: STRONG_PASSWORD,
          password_confirmation: STRONG_PASSWORD
        }
      }
    end

    assert_response :forbidden
  end

  test "admin cannot reset their own password from user management" do
    assert_no_changes -> { identities(:kevin).reload.password_digest } do
      patch user_password_path(users(:kevin)), params: {
        user: {
          password: STRONG_PASSWORD,
          password_confirmation: STRONG_PASSWORD
        }
      }
    end

    assert_response :forbidden
  end

  test "non-admin cannot reset another user's password" do
    logout_and_sign_in_as :jz

    assert_no_changes -> { identities(:david).reload.password_digest } do
      patch user_password_path(users(:david)), params: {
        user: {
          password: STRONG_PASSWORD,
          password_confirmation: STRONG_PASSWORD
        }
      }
    end

    assert_response :forbidden
  end

  test "rejects weak password" do
    assert_no_changes -> { identities(:david).reload.password_digest } do
      patch user_password_path(users(:david)), params: {
        user: {
          password: "short",
          password_confirmation: "short"
        }
      }
    end

    assert_redirected_to account_settings_path
    follow_redirect!
    assert_match "Password is too short", response.body
  end
end
