require "test_helper"

class AuditEventTest < ActiveSupport::TestCase
  test "record stores current request context and safe metadata" do
    Current.user = users(:kevin)
    Current.request_id = "request-123"
    Current.ip_address = "203.0.113.10"
    Current.user_agent = "Cactus Test Browser"

    audit_event = nil
    assert_difference -> { AuditEvent.count }, +1 do
      audit_event = AuditEvent.record(
        action: "card.triaged",
        auditable: cards(:logo),
        metadata: { changed_fields: [ :status ], notes_present: true }
      )
    end

    assert_equal accounts("37s"), audit_event.account
    assert_equal users(:kevin), audit_event.user
    assert_equal "card.triaged", audit_event.action
    assert_equal cards(:logo), audit_event.auditable
    assert_equal [ "status" ], audit_event.metadata["changed_fields"]
    assert_equal true, audit_event.metadata["notes_present"]
    assert_equal "request-123", audit_event.request_id
    assert_equal "203.0.113.10", audit_event.ip_address
    assert_equal "Cactus Test Browser", audit_event.user_agent
  end

  test "validates user belongs to audit account" do
    audit_event = AuditEvent.new(
      account: accounts("37s"),
      user: users(:mike),
      action: "user.role_updated"
    )

    assert_not audit_event.valid?
    assert_includes audit_event.errors[:user], "must belong to the audit event account"
  end

  test "record tolerates nil metadata" do
    audit_event = AuditEvent.record(action: "system.checked", metadata: nil)

    assert_equal({}, audit_event.metadata)
  end

  test "validates auditable belongs to audit account" do
    audit_event = AuditEvent.new(
      account: accounts("37s"),
      user: users(:kevin),
      action: "training_example.approved",
      auditable: cards(:radio)
    )

    assert_not audit_event.valid?
    assert_includes audit_event.errors[:auditable], "must belong to the audit event account"
  end
end
