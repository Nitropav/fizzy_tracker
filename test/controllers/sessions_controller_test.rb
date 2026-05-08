require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    untenanted do
      get new_session_path
    end

    assert_response :success
    assert_select "input[type=email][name=email_address][autocomplete=username]"
    assert_select "input[type=email][name=email_address][autocomplete='username webauthn']", count: 0
    assert_select "input[type=password][name=password]"
    assert_no_match "Sign in with a passkey", response.body
  end

  test "new redirects authenticated users" do
    sign_in_as :kevin

    untenanted do
      get new_session_path
      assert_redirected_to landing_url(script_name: accounts("37s").slug)
    end
  end

  test "create" do
    identity = identities(:kevin)

    untenanted do
      assert_no_difference -> { MagicLink.count } do
        post session_path, params: { email_address: identity.email_address, password: "password" }
      end

      assert_redirected_to landing_url(script_name: accounts("37s").slug)
      assert cookies.get_cookie("session_token").present?
      assert_nil flash[:magic_link_code]
    end
  end

  test "create rejects wrong password" do
    identity = identities(:kevin)

    untenanted do
      assert_no_difference -> { MagicLink.count } do
        post session_path, params: { email_address: identity.email_address, password: "wrong-password" }
      end

      assert_redirected_to new_session_path
      assert_equal "Check your email and password.", flash[:alert]
      assert_not cookies.get_cookie("session_token").present?
    end
  end

  test "create rejects missing credentials without raising" do
    untenanted do
      post session_path, params: {}

      assert_redirected_to new_session_path
      assert_equal "Check your email and password.", flash[:alert]
      assert_not cookies.get_cookie("session_token").present?
    end
  end

  test "create via JSON rejects missing credentials without raising" do
    untenanted do
      post session_path(format: :json), params: {}

      assert_response :unauthorized
      assert_equal "Check your email and password.", @response.parsed_body["message"]
    end
  end

  test "create for a new user" do
    untenanted do
      assert_no_difference -> { MagicLink.count } do
        assert_no_difference -> { Identity.count } do
          post session_path,
            params: { email_address: "nonexistent-#{SecureRandom.hex(6)}@example.com", password: "password" }
        end
      end

      assert_redirected_to new_session_path
      assert_equal "Check your email and password.", flash[:alert]
    end
  end

  test "create for a new user when single tenant mode already has a tenant" do
    with_multi_tenant_mode(false) do
      untenanted do
        assert_no_difference -> { MagicLink.count } do
          assert_no_difference -> { Identity.count } do
            post session_path,
              params: { email_address: "nonexistent-#{SecureRandom.hex(6)}@example.com", password: "password" }
          end
        end

        assert_redirected_to new_session_path
      end
    end
  end

  test "create with invalid email address" do
    # Avoid Sentry exceptions when attackers try to stuff invalid emails. The browser performs form
    # field validation that should normally prevent this from occurring, so I'm not worried about
    # returning proper validation errors.
    without_action_dispatch_exception_handling do
      untenanted do
        assert_no_difference -> { Identity.count } do
          post session_path, params: { email_address: "not-a-valid-email", password: "password" }
        end

        assert_response :redirect
        assert_redirected_to new_session_path
      end
    end
  end

  test "destroy" do
    sign_in_as :kevin

    untenanted do
      delete session_path

      assert_redirected_to new_session_path
      assert_not cookies[:session_token].present?
    end
  end

  test "create via JSON" do
    untenanted do
      post session_path(format: :json), params: { email_address: identities(:david).email_address, password: "password" }
      assert_response :created
      assert @response.parsed_body["session_token"].present?
      assert_equal false, @response.parsed_body["requires_signup_completion"]
    end
  end

  test "create via JSON rejects wrong password" do
    untenanted do
      post session_path(format: :json), params: { email_address: identities(:david).email_address, password: "wrong-password" }
      assert_response :unauthorized
      assert_equal "Check your email and password.", @response.parsed_body["message"]
    end
  end

  test "create for a new user via JSON" do
    new_email = "new-user-#{SecureRandom.hex(6)}@example.com"

    untenanted do
      assert_no_difference -> { Identity.count } do
        assert_no_difference -> { MagicLink.count } do
          post session_path(format: :json), params: { email_address: new_email, password: "password" }
        end
      end
      assert_response :unauthorized
      assert_equal "Check your email and password.", @response.parsed_body["message"]
    end
  end

  test "create with invalid email address via JSON" do
    untenanted do
      assert_no_difference -> { Identity.count } do
        post session_path(format: :json), params: { email_address: "not-a-valid-email", password: "password" }
      end
      assert_response :unauthorized
      assert_equal "Check your email and password.", @response.parsed_body["message"]
    end
  end

  test "destroy via JSON" do
    sign_in_as :kevin

    untenanted do
      delete session_path(format: :json)

      assert_response :no_content
      assert_not cookies[:session_token].present?
    end
  end
end
