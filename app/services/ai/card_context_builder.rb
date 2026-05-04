module Ai
  class CardContextBuilder
    def initialize(card)
      @card = card
    end

    def build
      {
        "card" => card_payload,
        "account" => account_payload,
        "board" => board_payload,
        "column" => column_payload,
        "creator" => user_payload(card.creator),
        "assignees" => card.assignees.map { user_payload(it) },
        "tags" => card.tags.map { tag_payload(it) },
        "steps" => card.steps.map { step_payload(it) },
        "comments" => comments.map { comment_payload(it) },
        "events" => activity_events.map { event_payload(it) },
        "attachments" => attachments_payload,
        "code_links" => code_links.map { code_link_payload(it) },
        "resolution_record" => resolution_record_payload
      }
    end

    private
      attr_reader :card

      def card_payload
        {
          "id" => card.id,
          "number" => card.number,
          "title" => card.title.to_s,
          "description" => plain_text(card.description),
          "status" => card.status,
          "cactus_workflow_state" => card.cactus_workflow_state,
          "workflow_state" => workflow_state,
          "created_at" => timestamp(card.created_at),
          "updated_at" => timestamp(card.updated_at),
          "last_active_at" => timestamp(card.last_active_at),
          "closed" => card.closed?,
          "postponed" => card.postponed?,
          "triaged" => card.triaged?
        }
      end

      def account_payload
        {
          "id" => card.account.id,
          "name" => card.account.name,
          "external_account_id" => card.account.external_account_id
        }
      end

      def board_payload
        {
          "id" => card.board.id,
          "name" => card.board.name,
          "all_access" => card.board.all_access?
        }
      end

      def column_payload
        return unless card.column

        {
          "id" => card.column.id,
          "name" => card.column.name,
          "color" => card.column.color
        }
      end

      def user_payload(user)
        {
          "id" => user.id,
          "name" => user.name,
          "role" => user.role,
          "email" => user.identity&.email_address
        }
      end

      def tag_payload(tag)
        {
          "id" => tag.id,
          "title" => tag.title
        }
      end

      def step_payload(step)
        {
          "id" => step.id,
          "content" => step.content,
          "completed" => step.completed?,
          "created_at" => timestamp(step.created_at)
        }
      end

      def comment_payload(comment)
        {
          "id" => comment.id,
          "body" => plain_text(comment.body),
          "creator" => user_payload(comment.creator),
          "system" => comment.creator.system?,
          "created_at" => timestamp(comment.created_at)
        }
      end

      def event_payload(event)
        {
          "id" => event.id,
          "action" => event.action.to_s,
          "creator" => user_payload(event.creator),
          "eventable_type" => event.eventable_type,
          "particulars" => event.particulars || {},
          "created_at" => timestamp(event.created_at)
        }
      end

      def attachments_payload
        attachment_sources.flat_map do |source|
          source.attachments.map { attachment_payload(it, source) }
        end
      end

      def attachment_payload(attachment, source)
        blob = attachment.blob

        {
          "id" => attachment.id,
          "record_type" => source.class.name,
          "record_id" => source.id,
          "filename" => blob.filename.to_s,
          "content_type" => blob.content_type,
          "byte_size" => blob.byte_size
        }
      end

      def resolution_record_payload
        return unless card.resolution_record

        record = card.resolution_record

        {
          "gate_one_status" => record.gate_one_status,
          "gate_two_status" => record.gate_two_status,
          "missing_gate_one_fields" => record.missing_gate_one_fields.map(&:to_s),
          "missing_gate_two_fields" => record.missing_gate_two_fields.map(&:to_s),
          "problem_description" => record.problem_description,
          "reproduction_steps" => record.reproduction_steps,
          "expected_behavior" => record.expected_behavior,
          "actual_behavior" => record.actual_behavior,
          "environment_context" => record.environment_context,
          "structured_summary" => record.structured_summary,
          "priority" => record.priority,
          "category" => record.category,
          "domain" => record.domain,
          "severity" => record.severity,
          "suggested_primitives" => record.suggested_primitives,
          "root_cause" => record.root_cause,
          "fix_summary" => record.fix_summary,
          "verification_steps" => record.verification_steps,
          "linked_commit_shas" => record.linked_commit_shas,
          "linked_pr_urls" => record.linked_pr_urls,
          "code_evidence_present" => record.code_evidence_present? || code_links.any?,
          "legacy_import" => record.legacy_import?,
          "legacy_source" => record.legacy_source,
          "legacy_external_id" => record.legacy_external_id,
          "legacy_metadata" => record.legacy_metadata,
          "legacy_imported_at" => timestamp(record.legacy_imported_at),
          "gate_one_legacy" => record.gate_one_legacy?,
          "needs_structuring" => record.needs_structuring?,
          "verified_at" => timestamp(record.verified_at)
        }
      end

      def code_link_payload(code_link)
        {
          "id" => code_link.id,
          "provider" => code_link.provider,
          "external_type" => code_link.external_type,
          "external_id" => code_link.external_id,
          "repository" => code_link.repository,
          "sha" => code_link.sha,
          "title" => code_link.title,
          "url" => code_link.url,
          "metadata" => code_link.metadata,
          "created_at" => timestamp(code_link.created_at)
        }
      end

      def workflow_state
        case
        when card.closed? then "closed"
        when card.postponed? then "not_now"
        when card.triaged? then card.column.name
        when card.published? then "needs_triage"
        else "draft"
        end
      end

      def comments
        @comments ||= card.comments.chronologically.includes(:creator, creator: :identity).with_rich_text_body.to_a
      end

      def activity_events
        @activity_events ||= begin
          relation = card.events
          relation = relation.or(Event.where(eventable: comments)) if comments.any?
          relation.chronologically.includes(:creator, creator: :identity).to_a
        end
      end

      def attachment_sources
        [ card, *comments ]
      end

      def code_links
        @code_links ||= card.code_links.chronologically.to_a
      end

      def plain_text(rich_text)
        return "" if rich_text.blank?

        if rich_text.respond_to?(:to_plain_text)
          rich_text.to_plain_text
        else
          rich_text.to_s
        end.strip
      end

      def timestamp(value)
        value&.iso8601
      end
  end
end
