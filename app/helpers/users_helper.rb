module UsersHelper
  def role_display_name(user)
    case user.role
    when "admin" then "Administrator"
    else user.role.titleize
    end
  end

  def cactus_role_options
    User::CactusRole::ROLES.map { |role| [ role.titleize, role ] }
  end

  def cactus_role_display_name(user)
    user.cactus_role.titleize
  end
end
