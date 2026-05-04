class TrainingExampleExport < ApplicationRecord
  STATUSES = %w[ completed failed ].freeze

  belongs_to :account
  belongs_to :user

  enum :status, STATUSES.index_by(&:itself), default: :completed

  attribute :training_example_ids, default: -> { [] }

  validates :filename, presence: true
  validates :example_count, numericality: { greater_than_or_equal_to: 0 }
  validates :completed_at, presence: true
  validate :user_matches_account

  scope :latest_first, -> { order(created_at: :desc, id: :desc) }

  def training_examples
    examples_by_id = account.training_examples.where(id: training_example_ids).index_by(&:id)

    training_example_ids.filter_map { examples_by_id[it] }
  end

  private
    def user_matches_account
      return if user.blank? || account.blank? || user.account_id == account_id

      errors.add(:user, "must belong to the export account")
    end
end
