class SessionsController < ApplicationController
  include ActionPack::Passkey::Request

  disallow_account_scope
  require_unauthenticated_access except: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limit_exceeded

  layout "public"

  def new
    @authentication_options = passkey_authentication_options
  end

  def create
    if identity = Identity.find_by(email_address: email_address)
      sign_in_with_password identity
    else
      invalid_credentials
    end
  end

  def destroy
    terminate_session

    respond_to do |format|
      format.html { redirect_to_logout_url }
      format.json { head :no_content }
    end
  end

  private
    def email_address
      params[:email_address].to_s.strip.downcase
    end

    def password
      params[:password].to_s
    end

    def rate_limit_exceeded
      rate_limit_exceeded_message = "Try again later."

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: rate_limit_exceeded_message }
        format.json { render json: { message: rate_limit_exceeded_message }, status: :too_many_requests }
      end
    end

    def sign_in_with_password(identity)
      if identity.authenticate(password)
        start_new_session_for identity

        respond_to do |format|
          format.html { redirect_to after_authentication_url, notice: "Signed in." }
          format.json { render json: { session_token: session_token, requires_signup_completion: false }, status: :created }
        end
      else
        invalid_credentials
      end
    end

    def invalid_credentials
      message = "Check your email and password."

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: message }
        format.json { render json: { message: message }, status: :unauthorized }
      end
    end
end
