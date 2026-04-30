class PasswordMailer < ApplicationMailer
  RESET_TOKEN_EXPIRATION = 30.minutes

  def reset(identity)
    @identity = identity
    @token = identity.signed_id(purpose: :password_reset, expires_in: RESET_TOKEN_EXPIRATION)

    mail to: identity.email_address, subject: "Reset your Fizzy password"
  end
end
