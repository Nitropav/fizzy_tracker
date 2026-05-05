unless Rails.env.development?
  puts "WARN: Seeding is configured for development bootstrap only."
else
  require "active_support/testing/time_helpers"
  include ActiveSupport::Testing::TimeHelpers

  DEFAULT_ADMIN_PASSWORD = "CactusAdmin123!".freeze

  def bootstrap_cactus_account
    account_name = ENV.fetch("CACTUS_ACCOUNT_NAME", "Cactus Bug Tracker")
    external_account_id = ENV["CACTUS_ACCOUNT_EXTERNAL_ID"].presence&.to_i
    default_project_name = ENV.fetch("CACTUS_DEFAULT_PROJECT_NAME", "Cactus Product Bugs")
    admin_name = ENV.fetch("CACTUS_ADMIN_NAME", "Cactus Admin")
    admin_email = ENV.fetch("CACTUS_ADMIN_EMAIL", "admin@cactus.local").strip.downcase
    admin_password = ENV.fetch("CACTUS_ADMIN_PASSWORD", DEFAULT_ADMIN_PASSWORD)

    identity = Identity.find_or_initialize_by(email_address: admin_email)
    identity.assign_attributes(staff: true)
    identity.assign_attributes(password: admin_password, password_confirmation: admin_password) if identity.new_record? || identity.password_digest.blank?
    identity.save!

    account = Account.joins(users: :identity).find_by(name: account_name, identities: { email_address: admin_email })
    configured_account = Account.find_by(external_account_id: external_account_id) if external_account_id

    if account.nil? && configured_account&.users&.joins(:identity)&.exists?(identities: { email_address: admin_email })
      account = configured_account
    elsif account.nil? && configured_account.present?
      puts "WARN: CACTUS_ACCOUNT_EXTERNAL_ID=#{external_account_id} is already used by '#{configured_account.name}', creating a separate Cactus account with a new slug."
    end

    if account.nil?
      account_attributes = { name: account_name }
      account_attributes[:external_account_id] = external_account_id if external_account_id && configured_account.nil?

      account = Account.create_with_owner(
        account: account_attributes,
        owner: {
          name: admin_name,
          identity: identity,
          cactus_role: "reviewer"
        }
      )
    else
      account.update!(name: account_name)
      account.users.find_or_create_by!(role: :system) { |user| user.name = "System" }
      account.users.find_or_initialize_by(identity: identity).tap do |user|
        user.assign_attributes(
          name: admin_name,
          role: :owner,
          cactus_role: "reviewer",
          verified_at: Time.current,
          active: true
        )
        user.save!
      end
    end

    admin_user = account.users.find_by!(identity: identity)
    Current.account = account
    Current.user = admin_user

    project = account.boards.find_or_initialize_by(name: default_project_name)
    project.assign_attributes(creator: admin_user, all_access: true)
    project.save!
    project.accesses.find_or_create_by!(user: admin_user) do |access|
      access.account = account
      access.involvement = "watching"
    end

    puts "Seeded Cactus account:"
    puts "  URL: #{account.slug}"
    puts "  Project: #{project.name}"
    puts "  Admin email: #{admin_email}"
    puts "  Admin password: #{admin_password}"
  end

  def seed_sample_accounts
    def seed_account(name)
      print "  #{name}..."
      elapsed = Benchmark.realtime { require_relative "seeds/#{name}" }
      puts " #{elapsed.round(2)} sec"
    end

    def create_tenant(signal_account_name)
      tenant_id = ActiveRecord::FixtureSet.identify signal_account_name
      email_address = "david@example.com"
      password = ENV.fetch("SAMPLE_ADMIN_PASSWORD", DEFAULT_ADMIN_PASSWORD)
      identity = Identity.find_or_initialize_by(email_address: email_address)
      identity.assign_attributes(password: password, password_confirmation: password, staff: true) if identity.new_record? || identity.password_digest.blank?
      identity.save!

      unless account = Account.find_by(external_account_id: tenant_id)
        account = Account.create_with_owner(
          account: {
            external_account_id: tenant_id,
            name: signal_account_name
          },
          owner: {
            name: "David Heinemeier Hansson",
            identity: identity,
            cactus_role: "reviewer"
          }
        )
      end
      Current.account = account
    end

    def find_or_create_user(full_name, email_address)
      password = ENV.fetch("SAMPLE_USER_PASSWORD", DEFAULT_ADMIN_PASSWORD)
      identity = Identity.find_or_initialize_by(email_address: email_address)
      identity.assign_attributes(password: password, password_confirmation: password) if identity.new_record? || identity.password_digest.blank?
      identity.save!

      if user = identity.users.find_by(account: Current.account)
        user
      else
        User.create!(name: full_name, identity: identity, account: Current.account, verified_at: Time.current)
      end
    end

    def login_as(user)
      Current.session = user.identity.sessions.create
    end

    def create_board(name, creator: Current.user, all_access: true, access_to: [])
      Board.find_or_create_by!(name:, creator:, all_access:).tap { it.accesses.grant_to(access_to) }
    end

    def create_card(title, board:, description: nil, status: :published, creator: Current.user)
      board.cards.create!(title:, description:, creator:, status:)
    end

    seed_account "cleanslate"
    seed_account "37signals"
    seed_account "honcho"
  end

  bootstrap_cactus_account

  if ENV["SEED_SAMPLE_DATA"] == "true"
    seed_sample_accounts
  end
end
