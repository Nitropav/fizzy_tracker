require "test_helper"

class CactusRoleMatrixTest < ActionDispatch::IntegrationTest
  ROLE_MATRIX = {
    reporter: {
      user: :david,
      role: :member,
      cactus_role: :reporter,
      menu_visible: [ "Cactus Home", "New Issue" ],
      menu_hidden: [ "Cactus Queue", "My Work", "Projects", "Pipeline Dashboard", "Integrations", "Audit Log", "Training Examples", "Import Asana Tasks", "Legacy Asana Issues", "Account Settings" ],
      allowed: [ :home, :new_issue ],
      denied: [ :queue, :work, :training_examples, :training_exports, :dashboard, :integrations, :asana_import, :asana_issues, :audit, :account_settings ]
    },
    developer: {
      user: :david,
      role: :member,
      cactus_role: :developer,
      menu_visible: [ "Cactus Home", "New Issue", "My Work" ],
      menu_hidden: [ "Cactus Queue", "Pipeline Dashboard", "Integrations", "Audit Log", "Training Examples", "Import Asana Tasks", "Legacy Asana Issues", "Account Settings" ],
      allowed: [ :home, :new_issue, :work ],
      denied: [ :queue, :training_examples, :training_exports, :dashboard, :integrations, :asana_import, :asana_issues, :audit, :account_settings ]
    },
    support: {
      user: :jz,
      role: :member,
      cactus_role: :support,
      menu_visible: [ "Cactus Home", "New Issue", "Cactus Queue", "Import Asana Tasks", "Legacy Asana Issues" ],
      menu_hidden: [ "My Work", "Pipeline Dashboard", "Integrations", "Audit Log", "Training Examples", "Account Settings" ],
      allowed: [ :home, :new_issue, :queue, :asana_import, :asana_issues ],
      denied: [ :work, :training_examples, :training_exports, :dashboard, :integrations, :audit, :account_settings ]
    },
    reviewer: {
      user: :david,
      role: :member,
      cactus_role: :reviewer,
      menu_visible: [ "Cactus Home", "New Issue", "Pipeline Dashboard", "Training Examples" ],
      menu_hidden: [ "Cactus Queue", "My Work", "Integrations", "Audit Log", "Import Asana Tasks", "Legacy Asana Issues", "Account Settings" ],
      allowed: [ :home, :new_issue, :training_examples, :training_exports, :dashboard ],
      denied: [ :queue, :work, :integrations, :asana_import, :asana_issues, :audit, :account_settings ]
    },
    admin: {
      user: :kevin,
      role: :admin,
      cactus_role: :support,
      menu_visible: [ "Cactus Home", "New Issue", "Cactus Queue", "My Work", "Projects", "Pipeline Dashboard", "Integrations", "Audit Log", "Training Examples", "Import Asana Tasks", "Legacy Asana Issues", "Account Settings" ],
      menu_hidden: [],
      allowed: [ :home, :new_issue, :queue, :work, :training_examples, :training_exports, :dashboard, :integrations, :asana_import, :asana_issues, :audit, :account_settings ],
      denied: []
    }
  }.freeze

  PAGE_TEXT = {
    home: [ :cactus_home_path, "Cactus Bug Tracker" ],
    new_issue: [ :new_cactus_issue_path, "Create issue" ],
    queue: [ :cactus_queues_path, "Cactus Queue" ],
    work: [ :cactus_work_path, "My Work" ],
    training_examples: [ :training_examples_path, "Training Examples" ],
    training_exports: [ :training_example_exports_path, "Training Export History" ],
    dashboard: [ :cactus_dashboard_path, "Cactus Dashboard" ],
    integrations: [ :cactus_integrations_path, "Cactus Integrations" ],
    asana_import: [ :new_legacy_imports_asana_path, "Import Asana Tasks" ],
    asana_issues: [ :legacy_imports_asana_issues_path, "Legacy Asana Issues" ],
    audit: [ :cactus_audit_events_path, "Audit Log" ],
    account_settings: [ :account_settings_path, "Account Settings" ]
  }.freeze

  test "cactus role matrix controls menu visibility and direct page access" do
    ROLE_MATRIX.each do |role_name, expectation|
      user = prepare_role_user(expectation)
      logout_and_sign_in_as user

      assert_menu_visibility role_name, expectation
      assert_allowed_pages role_name, expectation.fetch(:allowed)
      assert_denied_pages role_name, expectation.fetch(:denied)
    end
  end

  private
    def prepare_role_user(expectation)
      users(expectation.fetch(:user)).tap do |user|
        user.update!(
          role: expectation.fetch(:role),
          cactus_role: expectation.fetch(:cactus_role),
          active: true
        )
      end
    end

    def assert_menu_visibility(role_name, expectation)
      get my_menu_path

      assert_response :success, "#{role_name} should open the menu"

      expectation.fetch(:menu_visible).each do |label|
        assert_match label, response.body, "#{role_name} menu should include #{label}"
      end

      expectation.fetch(:menu_hidden).each do |label|
        assert_no_match label, response.body, "#{role_name} menu should not include #{label}"
      end
    end

    def assert_allowed_pages(role_name, pages)
      pages.each do |page|
        path, expected_text = path_and_text(page)

        get path

        assert_response :success, "#{role_name} should access #{page}"
        assert_match expected_text, response.body, "#{role_name} #{page} should render expected content"
      end
    end

    def assert_denied_pages(role_name, pages)
      pages.each do |page|
        path, = path_and_text(page)

        get path

        assert_response :forbidden, "#{role_name} should be denied from #{page}"
      end
    end

    def path_and_text(page)
      helper, expected_text = PAGE_TEXT.fetch(page)
      [ public_send(helper), expected_text ]
    end
end
