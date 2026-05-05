require "test_helper"

class Account::UserCreationTest < ActiveSupport::TestCase
  STRONG_PASSWORD = "correct horse battery staple"

  test "creates an identity and account user with roles" do
    creation = Account::UserCreation.new(
      account: accounts(:"37s"),
      name: "Created User",
      email_address: "Created.User@Example.com",
      password: STRONG_PASSWORD,
      password_confirmation: STRONG_PASSWORD,
      role: "admin",
      cactus_role: "developer"
    )

    assert creation.save
    assert creation.identity.authenticate(STRONG_PASSWORD)
    assert_equal "created.user@example.com", creation.identity.email_address
    assert_equal accounts(:"37s"), creation.user.account
    assert creation.user.admin?
    assert creation.user.developer?
    assert creation.user.verified?
  end

  test "rejects existing identity email" do
    creation = Account::UserCreation.new(
      account: accounts(:"37s"),
      name: "Duplicate User",
      email_address: identities(:david).email_address,
      password: STRONG_PASSWORD,
      password_confirmation: STRONG_PASSWORD,
      role: "member",
      cactus_role: "reporter"
    )

    assert_not creation.save
    assert_includes creation.errors[:email_address], "is already in use"
  end

  test "rejects special account roles" do
    creation = Account::UserCreation.new(
      account: accounts(:"37s"),
      name: "Owner User",
      email_address: "owner-user@example.com",
      password: STRONG_PASSWORD,
      password_confirmation: STRONG_PASSWORD,
      role: "owner",
      cactus_role: "reporter"
    )

    assert_not creation.save
    assert creation.errors[:role].present?
  end
end
