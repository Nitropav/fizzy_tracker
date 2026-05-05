class Account::UserCreation
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :email_address, :string
  attribute :password, :string
  attribute :password_confirmation, :string
  attribute :role, :string, default: "member"
  attribute :cactus_role, :string, default: "reporter"

  attr_accessor :account
  attr_reader :identity, :user

  validates :account, :name, presence: true
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: Identity::MINIMUM_PASSWORD_LENGTH }, confirmation: true
  validates :password_confirmation, presence: true
  validates :role, inclusion: { in: %w[ member admin ] }
  validates :cactus_role, inclusion: { in: User::CactusRole::ROLES }
  validate :email_address_is_available

  def email_address=(value)
    super(value.to_s.strip.downcase.presence)
  end

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      @identity = Identity.create!(
        email_address: email_address,
        password: password,
        password_confirmation: password_confirmation
      )

      @user = account.users.create!(
        identity: identity,
        name: name,
        role: role,
        cactus_role: cactus_role,
        verified_at: Time.current
      )
    end

    true
  rescue ActiveRecord::RecordInvalid => error
    error.record.errors.each { |active_model_error| errors.import(active_model_error) }
    false
  end

  private
    def email_address_is_available
      return if email_address.blank?

      errors.add(:email_address, "is already in use") if Identity.exists?(email_address: email_address)
    end
end
