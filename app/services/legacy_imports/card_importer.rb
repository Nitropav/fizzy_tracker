module LegacyImports
  class CardImporter
    Result = Data.define(:card, :resolution_record, :created)

    RECORD_FIELDS = %i[
      problem_description
      reproduction_steps
      expected_behavior
      actual_behavior
      environment_context
      structured_summary
      category
      domain
      severity
      suggested_primitives
      root_cause
      fix_summary
      verification_steps
      linked_commit_shas
      linked_pr_urls
      verified_at
    ].freeze

    def initialize(account:, board:, creator:)
      @account = account
      @board = board
      @creator = creator
    end

    def import(source:, external_id:, title:, description: nil, fields: {}, metadata: {}, resolved: false, created_at: nil, updated_at: nil)
      source = source.to_s
      external_id = external_id.to_s

      if (existing_record = find_existing_record(source, external_id))
        update_existing_record!(
          existing_record,
          title: title,
          fields: fields,
          metadata: metadata,
          resolved: resolved,
          updated_at: updated_at
        )

        return Result.new(existing_record.card, existing_record, false)
      end

      validate_scope!

      Current.with(account: account, user: creator, identity: creator.identity) do
        Card.transaction do
          card = create_card!(
            title: title,
            description: description,
            created_at: created_at,
            updated_at: updated_at
          )
          record = card.create_resolution_record!(
            resolution_attributes(
              source: source,
              external_id: external_id,
              fields: fields,
              metadata: metadata,
              resolved: resolved
            )
          )

          Result.new(card, record, true)
        end
      end
    end

    private
      attr_reader :account, :board, :creator

      def find_existing_record(source, external_id)
        Card::ResolutionRecord.find_by(
          account: account,
          legacy_source: source,
          legacy_external_id: external_id
        )
      end

      def update_existing_record!(record, title:, fields:, metadata:, resolved:, updated_at:)
        validate_scope!

        Current.with(account: account, user: creator, identity: creator.identity) do
          Card.transaction do
            update_existing_card!(record.card, title: title, updated_at: updated_at)
            update_existing_resolution_record!(
              record,
              fields: fields,
              metadata: metadata,
              resolved: resolved
            )
          end
        end
      end

      def update_existing_card!(card, title:, updated_at:)
        attrs = {}
        incoming_title = title.to_s.presence || card.title
        incoming_last_active_at = updated_at || card.last_active_at

        attrs[:title] = incoming_title if incoming_title != card.title
        attrs[:last_active_at] = incoming_last_active_at if incoming_last_active_at != card.last_active_at
        return if attrs.empty?

        card.update_columns(attrs.merge(updated_at: Time.current))
        card.reload
      end

      def update_existing_resolution_record!(record, fields:, metadata:, resolved:)
        incoming_fields = normalize_fields(fields)
        record.assign_attributes(fill_blank_fields(record, incoming_fields))
        record.legacy_metadata = merged_existing_metadata(
          existing_metadata: record.legacy_metadata,
          incoming_metadata: metadata,
          resolved: resolved
        )
        record.save! if record.changed?
      end

      def fill_blank_fields(record, incoming_fields)
        incoming_fields.each_with_object({}) do |(field, value), attrs|
          attrs[field] = value if value.present? && record.public_send(field).blank?
        end
      end

      def merged_existing_metadata(existing_metadata:, incoming_metadata:, resolved:)
        existing_metadata = existing_metadata.to_h.deep_stringify_keys
        incoming_metadata = incoming_metadata.to_h.deep_stringify_keys
        mergeable_metadata = incoming_metadata.except("stories", "attachments")

        existing_metadata.merge(mergeable_metadata).merge("completed" => resolved)
      end

      def validate_scope!
        raise ArgumentError, "board must belong to account" unless board.account_id == account.id
        raise ArgumentError, "creator must belong to account" unless creator.account_id == account.id
      end

      def create_card!(title:, description:, created_at:, updated_at:)
        board.cards.create!(
          account: account,
          creator: creator,
          status: :published,
          title: title.to_s.presence || "Legacy issue",
          description: description.to_s,
          created_at: created_at,
          updated_at: updated_at,
          last_active_at: updated_at || created_at || Time.current
        )
      end

      def resolution_attributes(source:, external_id:, fields:, metadata:, resolved:)
        normalized_fields = normalize_fields(fields)

        normalized_fields.merge(
          legacy_import: true,
          legacy_source: source,
          legacy_external_id: external_id,
          legacy_metadata: metadata.to_h.deep_stringify_keys.merge("completed" => resolved),
          legacy_imported_at: Time.current,
          gate_one_legacy: true,
          needs_structuring: needs_structuring?(normalized_fields, resolved)
        )
      end

      def normalize_fields(fields)
        fields.to_h.symbolize_keys.slice(*RECORD_FIELDS)
      end

      def needs_structuring?(fields, resolved)
        gate_one_missing = Card::ResolutionRecord::GATE_ONE_REQUIRED_FIELDS.any? { fields[it].blank? }
        gate_two_missing = Card::ResolutionRecord::GATE_TWO_REQUIRED_FIELDS.any? { fields[it].blank? }

        gate_one_missing || (resolved && gate_two_missing)
      end
  end
end
