require "test_helper"

class CactusAuditEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @audit_event = accounts("37s").audit_events.create!(
      user: users(:kevin),
      action: "training_example.approved",
      auditable: cards(:logo),
      metadata: {
        training_example_id: "example-1",
        review_notes_present: true
      },
      request_id: "request-1",
      ip_address: "203.0.113.10"
    )
  end

  test "index is visible to admins" do
    get cactus_audit_events_path

    assert_response :success
    assert_match "Cactus Audit Log", response.body
    assert_match "training_example.approved", response.body
    assert_match users(:kevin).name, response.body
    assert_match "request-1", response.body
    assert_match "203.0.113.10", response.body
  end

  test "index can filter by action" do
    accounts("37s").audit_events.create!(
      user: users(:kevin),
      action: "legacy_asana_import.queued",
      metadata: { marker: "hidden-import-marker" }
    )

    get cactus_audit_events_path(event_action: "training_example.approved")

    assert_response :success
    assert_match "training_example.approved", response.body
    assert_no_match "hidden-import-marker", response.body
  end

  test "index is account scoped" do
    accounts(:initech).audit_events.create!(
      user: users(:mike),
      action: "training_example.rejected",
      metadata: { training_example_id: "other-account" }
    )

    get cactus_audit_events_path

    assert_response :success
    assert_no_match "other-account", response.body
  end

  test "non admins cannot view audit events" do
    logout_and_sign_in_as :david

    get cactus_audit_events_path

    assert_response :forbidden
  end
end
