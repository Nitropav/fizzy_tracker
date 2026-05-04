require "test_helper"

class User::CactusRoleTest < ActiveSupport::TestCase
  test "reporter can create and update reporter-side issue data only" do
    user = users(:david)
    user.update!(cactus_role: :reporter)

    assert user.can_create_cactus_issue?
    assert user.can_update_cactus_gate_one?
    assert_not user.can_view_cactus_internal_issue_data?
    assert_not user.can_view_cactus_queue?
    assert_not user.can_work_cactus_issues?
    assert_not user.can_review_training_examples?
    assert_not user.can_create_cactus_project?
    assert_not user.can_manage_cactus_project?(boards(:writebook))
  end

  test "developer can claim work and update gate two" do
    user = users(:david)

    assert user.developer?
    assert user.can_work_cactus_issues?
    assert user.can_claim_cactus_issues?
    assert user.can_update_cactus_gate_two?
    assert user.can_resolve_cactus_issues?
    assert user.can_view_cactus_internal_issue_data?
    assert_not user.can_view_cactus_queue?
    assert_not user.can_review_training_examples?
    assert_not user.can_create_cactus_project?
    assert_not user.can_manage_cactus_project?(boards(:writebook))
  end

  test "support can triage assign and import issues" do
    user = users(:jz)

    assert user.support?
    assert user.can_view_cactus_queue?
    assert user.can_update_cactus_classification?
    assert user.can_assign_cactus_issues?
    assert user.can_import_cactus_issues?
    assert user.can_view_cactus_internal_issue_data?
    assert_not user.can_create_cactus_project?
    assert_not user.can_manage_cactus_project?(boards(:writebook))
    assert_not user.can_update_cactus_gate_two?
    assert_not user.can_resolve_cactus_issues?
  end

  test "reviewer can review training pipeline but not manage integrations" do
    user = users(:david)
    user.update!(cactus_role: :reviewer)

    assert user.can_review_training_examples?
    assert user.can_view_cactus_dashboard?
    assert user.can_view_cactus_internal_issue_data?
    assert_not user.can_manage_cactus_integrations?
    assert_not user.can_view_cactus_queue?
    assert_not user.can_create_cactus_project?
    assert_not user.can_manage_cactus_project?(boards(:writebook))
  end

  test "fizzy admins can access every cactus capability" do
    user = users(:kevin)

    assert user.admin?
    assert user.can_view_cactus_queue?
    assert user.can_work_cactus_issues?
    assert user.can_review_training_examples?
    assert user.can_manage_cactus_integrations?
    assert user.can_create_cactus_project?
    assert user.can_manage_cactus_project?(boards(:writebook))
  end
end
