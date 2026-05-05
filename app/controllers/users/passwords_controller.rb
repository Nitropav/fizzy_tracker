class Users::PasswordsController < ApplicationController
  before_action :set_user
  before_action :ensure_permission_to_reset_password

  def update
    if @user.identity.update(password_params)
      @user.identity.sessions.destroy_all
      redirect_to account_settings_path, notice: "Password reset for #{@user.name}."
    else
      redirect_to account_settings_path, alert: @user.identity.errors.full_messages.to_sentence
    end
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:user_id])
    end

    def ensure_permission_to_reset_password
      head :forbidden unless Current.user.can_administer?(@user)
    end

    def password_params
      params.expect(user: %i[ password password_confirmation ])
    end
end
