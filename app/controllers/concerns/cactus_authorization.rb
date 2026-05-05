module CactusAuthorization
  extend ActiveSupport::Concern

  private
    def ensure_can_create_cactus_issue
      deny_cactus_access unless Current.user.can_create_cactus_issue?
    end

    def ensure_can_view_cactus_queue
      deny_cactus_access unless Current.user.can_view_cactus_queue?
    end

    def ensure_can_work_cactus_issues
      deny_cactus_access unless Current.user.can_work_cactus_issues?
    end

    def ensure_can_update_cactus_gate_one
      deny_cactus_access unless Current.user.can_update_cactus_gate_one?
    end

    def ensure_can_update_cactus_gate_two
      deny_cactus_access unless Current.user.can_update_cactus_gate_two?
    end

    def ensure_can_update_cactus_resolution_record
      permissions = cactus_resolution_record_permissions
      allowed = permissions.all? { Current.user.public_send(it) }

      deny_cactus_access unless allowed
    end

    def ensure_can_update_cactus_classification
      deny_cactus_access unless Current.user.can_update_cactus_classification?
    end

    def ensure_can_assign_cactus_issues
      deny_cactus_access unless Current.user.can_assign_cactus_issues?
    end

    def ensure_can_claim_cactus_issues
      deny_cactus_access unless Current.user.can_claim_cactus_issues?
    end

    def ensure_can_resolve_cactus_issues
      deny_cactus_access unless Current.user.can_resolve_cactus_issues?
    end

    def ensure_can_review_training_examples
      deny_cactus_access unless Current.user.can_review_training_examples?
    end

    def ensure_can_view_cactus_dashboard
      deny_cactus_access unless Current.user.can_view_cactus_dashboard?
    end

    def ensure_can_manage_cactus_integrations
      deny_cactus_access unless Current.user.can_manage_cactus_integrations?
    end

    def ensure_can_import_cactus_issues
      deny_cactus_access unless Current.user.can_import_cactus_issues?
    end

    def ensure_can_create_cactus_project
      deny_cactus_access unless Current.user.can_create_cactus_project?
    end

    def ensure_can_manage_cactus_project
      deny_cactus_access unless Current.user.can_manage_cactus_project?(@board)
    end

    def deny_cactus_access
      respond_to do |format|
        format.html { render template: "cactus/forbidden", status: :forbidden }
        format.turbo_stream { render turbo_stream: turbo_stream_flash(alert: "Access denied."), status: :forbidden }
        format.json { render json: { error: "Access denied." }, status: :forbidden }
        format.any { head :forbidden }
      end
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
