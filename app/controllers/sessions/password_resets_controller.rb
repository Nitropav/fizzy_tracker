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
      params[:email_address].to_s.strip.downcase
    end

    def password
      params[:password].to_s
    end

    def password_confirmation
      params[:password_confirmation].to_s
    end

    def token
      params[:token].to_s
    end

    def identity_from_token
      Identity.find_signed(token, purpose: :password_reset)
    end

    def update_password(identity)
      if password.blank?
        flash.now[:alert] = "Password can't be blank."
        render :edit, status: :unprocessable_entity
        return
      end

      if password_confirmation.blank?
        flash.now[:alert] = "Password confirmation can't be blank."
        render :edit, status: :unprocessable_entity
        return
      end

      identity.assign_attributes(password: password, password_confirmation: password_confirmation)

      if identity.valid?
        identity.sessions.delete_all
        identity.save!
        start_new_session_for identity
        redirect_to after_authentication_url, notice: "Password updated."
      else
        flash.now[:alert] = identity.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    def redirect_to_new_reset
      redirect_to new_session_password_reset_path, alert: "That password reset link is invalid or expired."
    end
end
