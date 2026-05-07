module Cactus
  class Bootstrapper
    class ConfigError < StandardError; end

    DEFAULT_DEVELOPMENT_ADMIN_PASSWORD = "CactusAdmin123!".freeze
    DEFAULT_ACCOUNT_NAME = "Cactus Bug Tracker".freeze
    DEFAULT_PROJECT_NAME = "Cactus Product Bugs".freeze
    DEFAULT_ADMIN_NAME = "Cactus Admin".freeze
    DEFAULT_ADMIN_EMAIL = "admin@cactus.local".freeze

    Result = Struct.new(
      :account,
      :admin_user,
      :project,
      :created_account,
      :created_admin_identity,
      :created_admin_user,
      :created_project,
      :updated_admin_password,
      keyword_init: true
    )

    def self.from_env(env: ENV, rails_env: Rails.env)
      new(
        account_name: env.fetch("CACTUS_ACCOUNT_NAME", DEFAULT_ACCOUNT_NAME),
        external_account_id: parse_external_account_id(env["CACTUS_ACCOUNT_EXTERNAL_ID"]),
        default_project_name: env.fetch("CACTUS_DEFAULT_PROJECT_NAME", DEFAULT_PROJECT_NAME),
        admin_name: env.fetch("CACTUS_ADMIN_NAME", DEFAULT_ADMIN_NAME),
        admin_email: env.fetch("CACTUS_ADMIN_EMAIL", DEFAULT_ADMIN_EMAIL),
        admin_password: resolve_admin_password(env, rails_env),
        update_existing_password: truthy?(env["CACTUS_UPDATE_ADMIN_PASSWORD"])
      )
    end

    def self.parse_external_account_id(value)
      return if value.blank?

      Integer(value)
    rescue ArgumentError
      raise ConfigError, "CACTUS_ACCOUNT_EXTERNAL_ID must be an integer."
    end

    def self.resolve_admin_password(env, rails_env)
      env["CACTUS_ADMIN_PASSWORD"].presence || (DEFAULT_DEVELOPMENT_ADMIN_PASSWORD unless rails_env.production?)
    end

    def self.truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def initialize(account_name:, default_project_name:, admin_name:, admin_email:, admin_password: nil,
      external_account_id: nil, update_existing_password: false)
      @account_name = account_name.to_s.strip.presence || DEFAULT_ACCOUNT_NAME
      @default_project_name = default_project_name.to_s.strip.presence || DEFAULT_PROJECT_NAME
      @admin_name = admin_name.to_s.strip.presence || DEFAULT_ADMIN_NAME
      @admin_email = admin_email.to_s.strip.downcase.presence || DEFAULT_ADMIN_EMAIL
      @admin_password = admin_password
      @external_account_id = external_account_id
      @update_existing_password = update_existing_password
    end

    def run
      ActiveRecord::Base.transaction do
        identity = prepare_admin_identity
        account_result = prepare_account(identity)
        project_result = prepare_default_project(account_result[:account], account_result[:admin_user])

        Result.new(
          account: account_result[:account],
          admin_user: account_result[:admin_user],
          project: project_result[:project],
          created_account: account_result[:created_account],
          created_admin_identity: identity.previously_new_record?,
          created_admin_user: account_result[:created_admin_user],
          created_project: project_result[:created_project],
          updated_admin_password: identity.saved_change_to_password_digest?
        )
      end
    end

    private
      attr_reader :account_name, :default_project_name, :admin_name, :admin_email,
        :admin_password, :external_account_id, :update_existing_password

      def prepare_admin_identity
        identity = Identity.find_or_initialize_by(email_address: admin_email)
        requires_password = identity.new_record? || identity.password_digest.blank? || update_existing_password

        if requires_password
          raise ConfigError, "CACTUS_ADMIN_PASSWORD must be set for the initial admin user." if admin_password.blank?

          identity.assign_attributes(password: admin_password, password_confirmation: admin_password)
        end

        identity.staff = true
        identity.save!
        identity
      end

      def prepare_account(identity)
        account = find_target_account(identity)
        created_account = false

        if account.nil?
          account = create_account(identity)
          created_account = true
        else
          account.update!(name: account_name)
          account.users.find_or_create_by!(role: :system) { |user| user.name = "System" }
        end

        admin_user = identity.users.find_or_initialize_by(account: account)
        created_admin_user = created_account || admin_user.new_record?
        admin_user.assign_attributes(
          name: admin_name,
          role: :owner,
          cactus_role: "reviewer",
          verified_at: admin_user.verified_at || Time.current,
          active: true
        )
        admin_user.save!

        { account: account, admin_user: admin_user, created_account: created_account, created_admin_user: created_admin_user }
      end

      def find_target_account(identity)
        return Account.find_by(external_account_id: external_account_id) if external_account_id.present?

        identity.accounts.find_by(name: account_name) || Account.find_by(name: account_name)
      end

      def create_account(identity)
        account_attributes = { name: account_name }
        account_attributes[:external_account_id] = external_account_id if external_account_id.present?

        Account.create_with_owner(
          account: account_attributes,
          owner: {
            name: admin_name,
            identity: identity,
            cactus_role: "reviewer"
          }
        )
      end

      def prepare_default_project(account, admin_user)
        project = account.boards.find_or_initialize_by(name: default_project_name)
        created_project = project.new_record?

        project.assign_attributes(creator: admin_user, all_access: true)
        project.save!
        project.accesses.find_or_create_by!(user: admin_user) do |access|
          access.account = account
          access.involvement = "watching"
        end

        { project: project, created_project: created_project }
      end
  end
end
