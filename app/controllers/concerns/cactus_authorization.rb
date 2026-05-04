module CactusAuthorization
  extend ActiveSupport::Concern

  private
    def ensure_can_create_cactus_issue
      head :forbidden unless Current.user.can_create_cactus_issue?
    end

    def ensure_can_view_cactus_queue
      head :forbidden unless Current.user.can_view_cactus_queue?
    end

    def ensure_can_work_cactus_issues
      head :forbidden unless Current.user.can_work_cactus_issues?
    end

    def ensure_can_update_cactus_gate_one
      head :forbidden unless Current.user.can_update_cactus_gate_one?
    end

    def ensure_can_update_cactus_gate_two
      head :forbidden unless Current.user.can_update_cactus_gate_two?
    end

    def ensure_can_update_cactus_resolution_record
      permissions = cactus_resolution_record_permissions
      allowed = permissions.all? { Current.user.public_send(it) }

      head :forbidden unless allowed
    end

    def ensure_can_update_cactus_classification
      head :forbidden unless Current.user.can_update_cactus_classification?
    end

    def ensure_can_assign_cactus_issues
      head :forbidden unless Current.user.can_assign_cactus_issues?
    end

    def ensure_can_claim_cactus_issues
      head :forbidden unless Current.user.can_claim_cactus_issues?
    end

    def ensure_can_resolve_cactus_issues
      head :forbidden unless Current.user.can_resolve_cactus_issues?
    end

    def ensure_can_review_training_examples
      head :forbidden unless Current.user.can_review_training_examples?
    end

    def ensure_can_view_cactus_dashboard
      head :forbidden unless Current.user.can_view_cactus_dashboard?
    end

    def ensure_can_manage_cactus_integrations
      head :forbidden unless Current.user.can_manage_cactus_integrations?
    end

    def ensure_can_import_cactus_issues
      head :forbidden unless Current.user.can_import_cactus_issues?
    end

    def ensure_can_create_cactus_project
      head :forbidden unless Current.user.can_create_cactus_project?
    end

    def ensure_can_manage_cactus_project
      head :forbidden unless Current.user.can_manage_cactus_project?(@board)
    end

    def cactus_resolution_record_permissions
      submitted_keys = params.fetch(:card_resolution_record, {}).keys.map(&:to_s)
      permissions = []

      permissions << :can_update_cactus_gate_one? if (submitted_keys & Card::ResolutionRecord::GATE_ONE_REQUIRED_FIELDS.map(&:to_s)).any?
      permissions << :can_update_cactus_gate_two? if (submitted_keys & Card::ResolutionRecord::GATE_TWO_REQUIRED_FIELDS.map(&:to_s)).any?
      permissions << :can_update_cactus_classification? if (submitted_keys & %w[ structured_summary priority category domain severity suggested_primitives ]).any?

      permissions.presence || [ :can_update_cactus_gate_one? ]
    end
end
