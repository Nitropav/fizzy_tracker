module User::CactusRole
  extend ActiveSupport::Concern

  ROLES = %w[ reporter developer support reviewer ].freeze

  included do
    enum :cactus_role, ROLES.index_by(&:itself), default: :reporter, scopes: false, validate: true
  end

  def cactus_admin?
    admin?
  end

  def can_create_cactus_issue?
    active? && !system?
  end

  def can_view_cactus_queue?
    cactus_admin? || support?
  end

  def can_update_cactus_classification?
    can_view_cactus_queue?
  end

  def can_view_cactus_internal_issue_data?
    can_view_cactus_queue? || can_work_cactus_issues? || can_review_training_examples?
  end

  def can_assign_cactus_issues?
    can_view_cactus_queue?
  end

  def can_import_cactus_issues?
    cactus_admin? || support?
  end

  def can_create_cactus_project?
    cactus_admin?
  end

  def can_manage_cactus_project?(_project = nil)
    cactus_admin?
  end

  def can_work_cactus_issues?
    cactus_admin? || developer?
  end

  def can_claim_cactus_issues?
    can_work_cactus_issues?
  end

  def can_update_cactus_gate_one?
    can_create_cactus_issue?
  end

  def can_update_cactus_gate_two?
    can_work_cactus_issues?
  end

  def can_resolve_cactus_issues?
    can_work_cactus_issues?
  end

  def can_review_training_examples?
    cactus_admin? || reviewer?
  end

  def can_view_cactus_dashboard?
    cactus_admin? || reviewer?
  end

  def can_manage_cactus_integrations?
    cactus_admin?
  end
end
