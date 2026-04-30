module SessionTestHelper
  def parsed_cookies
    ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
  end

  def sign_in_as(identity)
    cookies.delete :session_token

    if identity.is_a?(User)
      user = identity
      identity = user.identity
      raise "User #{user.name} (#{user.id}) doesn't have an associated identity" unless identity
    elsif !identity.is_a?(Identity)
      identity = identities(identity)
    end

    untenanted do
      post session_development_login_path, params: { email_address: identity.email_address }
    end

    assert_response :redirect, "Development login should grant access"

    cookie = cookies.get_cookie "session_token"
    assert_not_nil cookie, "Expected session_token cookie to be set after sign in"
  end

  def logout_and_sign_in_as(identity)
    Session.delete_all
    sign_in_as identity
  end

  def sign_out
    untenanted do
      delete session_path
    end
    assert_not cookies[:session_token].present?
  end

  def with_current_user(user)
    user = users(user) unless user.is_a? User
    @old_session = Current.session
    begin
      Current.session = Session.new(identity: user.identity)
      yield
    ensure
      Current.session = @old_session
    end
  end

  def untenanted(&block)
    original_script_name = integration_session.default_url_options[:script_name]
    integration_session.default_url_options[:script_name] = ""
    yield
  ensure
    integration_session.default_url_options[:script_name] = original_script_name
  end

  def with_multi_tenant_mode(enabled)
    previous = Account.multi_tenant
    Account.multi_tenant = enabled
    yield
  ensure
    Account.multi_tenant = previous
  end
end
