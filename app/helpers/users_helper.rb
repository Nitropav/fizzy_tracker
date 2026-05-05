module UsersHelper
  def account_role_options
    [
      [ "Member", "member" ],
      [ "Admin", "admin" ]
    ]
  end

  def role_display_name(user)
    case user.role
    when "admin" then "Administrator"
    else user.role.titleize
    end
  end

  def account_role_description(role)
    case role.to_s
    when "admin" then "Can manage users, projects, integrations, imports, dashboard, and training review."
    else "Can sign in and use the Cactus workflow according to their Cactus role."
    end
  end

  def cactus_role_options
    User::CactusRole::ROLES.map { |role| [ role.titleize, role ] }
  end

  def cactus_role_display_name(user)
    user.cactus_role.titleize
  end

  def cactus_role_description(role)
    case role.to_s
    when "reporter" then "Creates issues and fills Gate 1 reporter-side context."
    when "developer" then "Claims assigned work, fills Gate 2, links code evidence, and resolves issues."
    when "support" then "Triage queue owner: classifies, assigns, imports legacy issues, and communicates with reporters."
    when "reviewer" then "Reviews training examples, exports approved JSONL, and monitors dashboard health."
    else "Cactus workflow role."
    end
  end
end
