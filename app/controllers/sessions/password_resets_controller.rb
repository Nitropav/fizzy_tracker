class Sessions::PasswordResetsController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access

  layout "public"

  def new
  end

  def create
    if identity = Identity.find_by(email_address: email_address)
      PasswordMailer.reset(identity).deliver_later
    end

    redirect_to new_session_path, notice: "If that email exists, password reset instructions have been sent."
  end

  def edit
    redirect_to_new_reset unless identity_from_token
  end

  def update
    if identity = identity_from_token
      update_password identity
    else
      redirect_to_new_reset
    end
  end

  private
    def email_address
      params.expect(:email_address)
    end

    def password
      params.expect(:password)
    end

    def token
      params.expect(:token)
    end

    def identity_from_token
      Identity.find_signed(token, purpose: :password_reset)
    end

    def update_password(identity)
      if password.length >= 8
        identity.sessions.delete_all
        identity.update!(password: password)
        start_new_session_for identity
        redirect_to after_authentication_url, notice: "Password updated."
      else
        flash.now[:alert] = "Password must be at least 8 characters."
        render :edit, status: :unprocessable_entity
      end
    end

    def redirect_to_new_reset
      redirect_to new_session_password_reset_path, alert: "That password reset link is invalid or expired."
    end
end
