require "test_helper"

class Cactus::BootstrapperTest < ActiveSupport::TestCase
  test "creates a standalone account, admin login, and default project" do
    email = "bootstrap-admin-#{SecureRandom.hex(4)}@example.com"
    external_account_id = 987_654_321

    result = nil
    Current.without_account do
      assert_difference -> { Account.count }, +1 do
        assert_difference -> { Identity.count }, +1 do
          assert_difference -> { User.count }, +2 do
            assert_difference -> { Board.count }, +1 do
              assert_difference -> { Column.count }, +1 do
                result = Cactus::Bootstrapper.new(
                  account_name: "Bootstrap Cactus",
                  external_account_id: external_account_id,
                  default_project_name: "Bootstrap Bugs",
                  admin_name: "Bootstrap Admin",
                  admin_email: email,
                  admin_password: "SecurePassword123!"
                ).run
              end
            end
          end
        end
      end
    end

    assert_equal "Bootstrap Cactus", result.account.name
    assert_equal external_account_id, result.account.external_account_id
    assert_equal "Bootstrap Bugs", result.project.name
    assert_equal result.account, result.project.account
    assert_equal "Bootstrap Admin", result.admin_user.name
    assert_predicate result.admin_user, :owner?
    assert_predicate result.admin_user, :reviewer?
    assert_predicate result.admin_user, :verified?
    assert_predicate result.account.system_user, :present?
    assert result.project.accesses.exists?(user: result.admin_user, involvement: "watching")
    assert result.project.columns.exists?(name: "In Progress")
    assert result.admin_user.identity.authenticate("SecurePassword123!")
    assert_equal "/#{external_account_id}", result.account.slug
    assert result.created_account
    assert result.created_admin_identity
    assert result.created_admin_user
    assert result.created_project
  end

  test "is idempotent for the same account and admin" do
    email = "idempotent-bootstrap-#{SecureRandom.hex(4)}@example.com"
    bootstrapper = Cactus::Bootstrapper.new(
      account_name: "Idempotent Cactus",
      default_project_name: "Idempotent Bugs",
      admin_name: "Idempotent Admin",
      admin_email: email,
      admin_password: "SecurePassword123!"
    )

    first_result = bootstrapper.run

    assert_no_difference -> { Account.count } do
      assert_no_difference -> { Identity.count } do
        assert_no_difference -> { User.count } do
          assert_no_difference -> { Board.count } do
            assert_no_difference -> { Column.count } do
              second_result = bootstrapper.run
              assert_equal first_result.account, second_result.account
              assert_equal first_result.admin_user, second_result.admin_user
              assert_equal first_result.project, second_result.project
              assert_not second_result.created_account
              assert_not second_result.created_admin_identity
              assert_not second_result.created_admin_user
              assert_not second_result.created_project
              assert first_result.project.columns.exists?(name: "In Progress")
            end
          end
        end
      end
    end
  end

  test "requires a password for a new admin identity" do
    error = assert_raises Cactus::Bootstrapper::ConfigError do
      Cactus::Bootstrapper.new(
        account_name: "Missing Password Cactus",
        default_project_name: "Missing Password Bugs",
        admin_name: "Missing Password Admin",
        admin_email: "missing-password-#{SecureRandom.hex(4)}@example.com",
        admin_password: nil
      ).run
    end

    assert_match "CACTUS_ADMIN_PASSWORD", error.message
  end

  test "does not rotate an existing password unless explicitly requested" do
    email = "password-rotation-#{SecureRandom.hex(4)}@example.com"

    first_result = Cactus::Bootstrapper.new(
      account_name: "Password Rotation Cactus",
      default_project_name: "Password Rotation Bugs",
      admin_name: "Password Rotation Admin",
      admin_email: email,
      admin_password: "OriginalPassword123!"
    ).run

    Cactus::Bootstrapper.new(
      account_name: "Password Rotation Cactus",
      default_project_name: "Password Rotation Bugs",
      admin_name: "Password Rotation Admin",
      admin_email: email,
      admin_password: "ChangedPassword123!"
    ).run

    assert first_result.admin_user.identity.reload.authenticate("OriginalPassword123!")
    assert_not first_result.admin_user.identity.authenticate("ChangedPassword123!")

    Cactus::Bootstrapper.new(
      account_name: "Password Rotation Cactus",
      default_project_name: "Password Rotation Bugs",
      admin_name: "Password Rotation Admin",
      admin_email: email,
      admin_password: "ChangedPassword123!",
      update_existing_password: true
    ).run

    assert first_result.admin_user.identity.reload.authenticate("ChangedPassword123!")
  end

  test "from_env uses development defaults but production requires an explicit initial password" do
    development_result = Cactus::Bootstrapper.from_env(
      env: {
        "CACTUS_ACCOUNT_NAME" => "Env Dev Cactus #{SecureRandom.hex(4)}",
        "CACTUS_DEFAULT_PROJECT_NAME" => "Env Dev Bugs",
        "CACTUS_ADMIN_NAME" => "Env Dev Admin",
        "CACTUS_ADMIN_EMAIL" => "env-dev-#{SecureRandom.hex(4)}@example.com"
      },
      rails_env: ActiveSupport::StringInquirer.new("development")
    ).run

    assert development_result.admin_user.identity.authenticate(Cactus::Bootstrapper::DEFAULT_DEVELOPMENT_ADMIN_PASSWORD)

    assert_raises Cactus::Bootstrapper::ConfigError do
      Cactus::Bootstrapper.from_env(
        env: {
          "CACTUS_ACCOUNT_NAME" => "Env Prod Cactus #{SecureRandom.hex(4)}",
          "CACTUS_DEFAULT_PROJECT_NAME" => "Env Prod Bugs",
          "CACTUS_ADMIN_NAME" => "Env Prod Admin",
          "CACTUS_ADMIN_EMAIL" => "env-prod-#{SecureRandom.hex(4)}@example.com"
        },
        rails_env: ActiveSupport::StringInquirer.new("production")
      ).run
    end
  end
end
