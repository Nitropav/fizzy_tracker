require "test_helper"

class PasswordMailerTest < ActionMailer::TestCase
  test "reset" do
    identity = identities(:kevin)
    email = PasswordMailer.reset(identity)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ identity.email_address ], email.to
    assert_equal "Reset your Fizzy password", email.subject
    assert_match "/session/password_reset/edit", email.body.encoded
  end
end
