class Users::RolesController < ApplicationController
  wrap_parameters :user, include: %i[ role cactus_role ]

  before_action :set_user
  before_action :ensure_permission_to_administer_user

  def update
    previous_role = @user.role
    previous_cactus_role = @user.cactus_role
    attributes = role_params
    @user.update!(attributes)

    AuditEvent.record(
      action: "user.role_updated",
      auditable: @user,
      metadata: {
        target_user_id: @user.id,
        changed_fields: attributes.keys,
        previous_role: previous_role,
        role: @user.role,
        previous_cactus_role: previous_cactus_role,
        cactus_role: @user.cactus_role
      }
    )

    respond_to do |format|
      format.html { redirect_to account_settings_path }
      format.json { head :no_content }
    end
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:user_id])
    end

    def ensure_permission_to_administer_user
      head :forbidden unless Current.user.can_administer?(@user)
    end

    def role_params
      user_params = params.require(:user)
      attributes = {}

      if user_params.key?(:role)
        attributes[:role] = user_params[:role].presence_in(%w[ member admin ]) || "member"
      end

      if user_params.key?(:cactus_role)
        attributes[:cactus_role] = user_params[:cactus_role].presence_in(User::CactusRole::ROLES) || "reporter"
      end

      attributes
    end
end
