class JoinCodesController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { head :too_many_requests }

  before_action :set_join_code
  before_action :ensure_join_code_is_valid
  before_action :set_identity, only: :create

  layout "public"

  def new
  end

  def create
    return unless authenticate_or_prepare_identity

    @join_code.redeem_if { |account| @identity.join(account) }
    user = User.active.find_by!(account: @join_code.account, identity: @identity)

    if @identity == Current.identity && user.setup?
      redirect_to landing_url(script_name: @join_code.account.slug)
    elsif @identity == Current.identity
      redirect_to new_users_verification_url(script_name: @join_code.account.slug)
    else
      terminate_session if Current.identity
      start_new_session_for @identity
      redirect_to new_users_verification_url(script_name: @join_code.account.slug)
    end
    end

  private
    def set_identity
      @identity = Identity.find_or_initialize_by(email_address: email_address)
    end

    def authenticate_or_prepare_identity
      return true if @identity == Current.identity

      if @identity.new_record?
        create_identity_with_password
      elsif @identity.password_digest.present?
        authenticate_identity
      else
        set_initial_password
      end
    end

    def create_identity_with_password
      @identity.password = password
      @identity.password_confirmation = password_confirmation

      if @identity.valid?
        @identity.save!
      else
        head :unprocessable_entity
        false
      end
    end

    def authenticate_identity
      if @identity.authenticate(password)
        true
      else
        redirect_to new_session_path, alert: "Check your email and password."
        false
      end
    end

    def set_initial_password
      @identity.assign_attributes(password: password, password_confirmation: password_confirmation)

      if @identity.valid?
        @identity.save!
      else
        head :unprocessable_entity
        false
      end
    end

    def email_address
      params[:email_address].to_s.strip.downcase
    end

    def password
      params[:password].to_s
    end

    def password_confirmation
      params[:password_confirmation].to_s
    end

    def set_join_code
      @join_code ||= Account::JoinCode.find_by(code: params.expect(:code), account: Current.account)
    end

    def ensure_join_code_is_valid
      if @join_code.nil?
        head :not_found
      elsif !@join_code.active?
        render :inactive, status: :gone
      end
    end
end
