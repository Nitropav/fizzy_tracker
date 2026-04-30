class Sessions::DevelopmentLoginsController < ApplicationController
  disallow_account_scope
  allow_unauthenticated_access

  before_action :ensure_local_environment

  layout "public"

  def create
    identity = Identity.find_by!(email_address: params.expect(:email_address))
    start_new_session_for identity

    redirect_to after_authentication_url
  end

  private
    def ensure_local_environment
      raise ActionController::RoutingError, "Not Found" unless Rails.env.local?
    end
end
