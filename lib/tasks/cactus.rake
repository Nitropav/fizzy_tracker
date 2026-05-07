namespace :cactus do
  desc "Bootstrap the Cactus account, owner login, and default project from CACTUS_* environment variables"
  task bootstrap: :environment do
    result = Cactus::Bootstrapper.from_env.run

    puts "Cactus bootstrap complete:"
    puts "  Account: #{result.account.name}"
    puts "  URL: #{result.account.slug}"
    puts "  Project: #{result.project.name}"
    puts "  Admin email: #{result.admin_user.identity.email_address}"
    puts "  Created account: #{result.created_account}"
    puts "  Created admin user: #{result.created_admin_user}"
    puts "  Created project: #{result.created_project}"
    puts "  Updated admin password: #{result.updated_admin_password}"
  end
end
