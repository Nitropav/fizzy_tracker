result = Cactus::Bootstrapper.from_env.run

puts "Seeded Cactus account:"
puts "  URL: #{result.account.slug}"
puts "  Project: #{result.project.name}"
puts "  Admin email: #{result.admin_user.identity.email_address}"
puts "  Admin password: set via CACTUS_ADMIN_PASSWORD"

if ENV["SEED_SAMPLE_DATA"] == "true"
  if !Rails.env.development?
    puts "WARN: SEED_SAMPLE_DATA is only supported in development. Skipping sample Fizzy data."
  else
    require "active_support/testing/time_helpers"
    include ActiveSupport::Testing::TimeHelpers

    DEFAULT_SAMPLE_PASSWORD = "CactusAdmin123!".freeze

    def seed_account(name)
      print "  #{name}..."
      elapsed = Benchmark.realtime { require_relative "seeds/#{name}" }
      puts " #{elapsed.round(2)} sec"
    end

    def create_tenant(signal_account_name)
      tenant_id = ActiveRecord::FixtureSet.identify signal_account_name
      email_address = "david@example.com"
      password = ENV.fetch("SAMPLE_ADMIN_PASSWORD", DEFAULT_SAMPLE_PASSWORD)
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
      password = ENV.fetch("SAMPLE_USER_PASSWORD", DEFAULT_SAMPLE_PASSWORD)
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
end
