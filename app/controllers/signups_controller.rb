class SignupsController < ApplicationController
  wrap_parameters :signup, include: %i[ email_address password ]

  disallow_account_scope
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_signup_path, alert: "Try again later." }
  before_action :redirect_authenticated_user
  before_action :enforce_tenant_limit

  layout "public"

  def new
    @signup = Signup.new
  end

  def create
    signup = Signup.new(signup_params)
    if signup.valid?(:identity_creation)
      start_new_session_for signup.create_identity
      respond_to do |format|
        format.html { redirect_to new_signup_completion_path }
        format.json { render json: { session_token: session_token, requires_signup_completion: true }, status: :created }
      end
    else
      head :unprocessable_entity
    end
  end

  private
    def redirect_authenticated_user
      redirect_to new_signup_completion_path if authenticated?
    end

    def enforce_tenant_limit
      redirect_to new_session_url unless Account.accepting_signups?
    end

    def signup_params
      params.expect signup: %i[ email_address password ]
    end
end
