class Account::SettingsController < ApplicationController
  wrap_parameters :account, include: %i[ name ]

  before_action :ensure_admin
  before_action :set_account

  def show
    respond_to do |format|
      format.html do
        @users = @account.users.active.alphabetically.includes(:identity)
        @user_creation = Account::UserCreation.new(account: @account)
      end
      format.json
    end
  end

  def update
    previous_name = @account.name
    attributes = account_params
    @account.update!(attributes)
    AuditEvent.record(
      action: "account.updated",
      auditable: @account,
      metadata: {
        changed_fields: attributes.keys,
        previous_name: previous_name,
        name: @account.name
      }
    )

    respond_to do |format|
      format.html { redirect_to account_settings_path }
      format.json { head :no_content }
    end
  end

  private
    def set_account
      @account = Current.account
    end

    def account_params
      params.expect account: %i[ name ]
    end
end
