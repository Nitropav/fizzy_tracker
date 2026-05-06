# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_06_123000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accesses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "accessed_at"
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.datetime "created_at", null: false
    t.string "involvement", limit: 255, default: "access_only", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id", "accessed_at"], name: "index_accesses_on_account_id_and_accessed_at"
    t.index ["board_id", "user_id"], name: "index_accesses_on_board_id_and_user_id", unique: true
    t.index ["board_id"], name: "index_accesses_on_board_id"
    t.index ["user_id"], name: "index_accesses_on_user_id"
  end

  create_table "account_cancellations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "initiated_by_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_cancellations_on_account_id", unique: true
  end

  create_table "account_external_id_sequences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "value", default: 0, null: false
    t.index ["value"], name: "index_account_external_id_sequences_on_value", unique: true
  end

  create_table "account_imports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "failure_reason", limit: 255
    t.uuid "identity_id", null: false
    t.string "status", limit: 255, default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_imports_on_account_id"
    t.index ["identity_id"], name: "index_account_imports_on_identity_id"
  end

  create_table "account_join_codes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "code", limit: 255, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "usage_count", default: 0, null: false
    t.bigint "usage_limit", default: 10, null: false
    t.index ["account_id", "code"], name: "index_account_join_codes_on_account_id_and_code", unique: true
  end

  create_table "accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "cards_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "external_account_id"
    t.string "name", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["external_account_id"], name: "index_accounts_on_external_account_id", unique: true
  end

  create_table "action_pack_passkeys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "aaguid", limit: 255
    t.boolean "backed_up"
    t.datetime "created_at", null: false
    t.string "credential_id", limit: 255, null: false
    t.uuid "holder_id", null: false
    t.string "holder_type", limit: 255, null: false
    t.string "name", limit: 255
    t.binary "public_key", null: false
    t.integer "sign_count", default: 0, null: false
    t.text "transports"
    t.datetime "updated_at", null: false
    t.index ["credential_id"], name: "index_action_pack_passkeys_on_credential_id", unique: true
    t.index ["holder_type", "holder_id"], name: "index_action_pack_passkeys_on_holder_type_and_holder_id"
  end

  create_table "action_text_rich_texts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", limit: 255, null: false
    t.uuid "record_id", null: false
    t.string "record_type", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_action_text_rich_texts_on_account_id"
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 255, null: false
    t.uuid "record_id", null: false
    t.string "record_type", limit: 255, null: false
    t.index ["account_id"], name: "index_active_storage_attachments_on_account_id"
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", limit: 255
    t.string "content_type", limit: 255
    t.datetime "created_at", null: false
    t.string "filename", limit: 255, null: false
    t.string "key", limit: 255, null: false
    t.text "metadata"
    t.string "service_name", limit: 255, null: false
    t.index ["account_id"], name: "index_active_storage_blobs_on_account_id"
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "blob_id", null: false
    t.string "variation_digest", limit: 255, null: false
    t.index ["account_id"], name: "index_active_storage_variant_records_on_account_id"
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.json "input_context", null: false
    t.json "metadata", null: false
    t.json "output", null: false
    t.string "run_type", limit: 255, null: false
    t.string "status", limit: 255, default: "pending", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["account_id", "run_type", "status"], name: "index_ai_runs_on_account_id_and_run_type_and_status"
    t.index ["account_id"], name: "index_ai_runs_on_account_id"
    t.index ["card_id", "run_type", "created_at"], name: "index_ai_runs_on_card_id_and_run_type_and_created_at"
    t.index ["card_id"], name: "index_ai_runs_on_card_id"
    t.index ["user_id"], name: "index_ai_runs_on_user_id"
  end

  create_table "assignees_filters", id: false, force: :cascade do |t|
    t.uuid "assignee_id", null: false
    t.uuid "filter_id", null: false
    t.index ["assignee_id"], name: "index_assignees_filters_on_assignee_id"
    t.index ["filter_id"], name: "index_assignees_filters_on_filter_id"
  end

  create_table "assigners_filters", id: false, force: :cascade do |t|
    t.uuid "assigner_id", null: false
    t.uuid "filter_id", null: false
    t.index ["assigner_id"], name: "index_assigners_filters_on_assigner_id"
    t.index ["filter_id"], name: "index_assigners_filters_on_filter_id"
  end

  create_table "assignments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "assignee_id", null: false
    t.uuid "assigner_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_assignments_on_account_id"
    t.index ["assignee_id", "card_id"], name: "index_assignments_on_assignee_id_and_card_id", unique: true
    t.index ["card_id"], name: "index_assignments_on_card_id"
  end

  create_table "board_publications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.datetime "created_at", null: false
    t.string "key", limit: 255
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_board_publications_on_account_id"
    t.index ["board_id"], name: "index_board_publications_on_board_id"
    t.index ["key"], name: "index_board_publications_on_key", unique: true
  end

  create_table "boards", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.boolean "all_access", default: false, null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.string "name", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_boards_on_account_id"
    t.index ["creator_id"], name: "index_boards_on_creator_id"
  end

  create_table "boards_filters", id: false, force: :cascade do |t|
    t.uuid "board_id", null: false
    t.uuid "filter_id", null: false
    t.index ["board_id"], name: "index_boards_filters_on_board_id"
    t.index ["filter_id"], name: "index_boards_filters_on_filter_id"
  end

  create_table "card_activity_spikes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_card_activity_spikes_on_account_id"
    t.index ["card_id"], name: "index_card_activity_spikes_on_card_id", unique: true
  end

  create_table "card_code_links", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.string "external_id", limit: 255, null: false
    t.string "external_type", limit: 255, null: false
    t.json "metadata", null: false
    t.string "provider", limit: 255, null: false
    t.string "repository", limit: 255
    t.string "sha", limit: 255
    t.text "title"
    t.datetime "updated_at", null: false
    t.text "url"
    t.index ["account_id", "provider", "external_type", "external_id", "card_id"], name: "index_card_code_links_on_unique_external_reference", unique: true
    t.index ["account_id", "provider", "repository"], name: "idx_on_account_id_provider_repository_983372b97d"
    t.index ["account_id", "sha"], name: "index_card_code_links_on_account_id_and_sha"
    t.index ["account_id"], name: "index_card_code_links_on_account_id"
    t.index ["card_id"], name: "index_card_code_links_on_card_id"
  end

  create_table "card_goldnesses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_card_goldnesses_on_account_id"
    t.index ["card_id"], name: "index_card_goldnesses_on_card_id", unique: true
  end

  create_table "card_not_nows", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["account_id"], name: "index_card_not_nows_on_account_id"
    t.index ["card_id"], name: "index_card_not_nows_on_card_id", unique: true
    t.index ["user_id"], name: "index_card_not_nows_on_user_id"
  end

  create_table "card_resolution_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.text "actual_behavior"
    t.uuid "card_id", null: false
    t.string "category", limit: 255
    t.datetime "created_at", null: false
    t.string "domain", limit: 255
    t.text "environment_context"
    t.text "expected_behavior"
    t.text "fix_summary"
    t.boolean "gate_one_legacy", default: false, null: false
    t.string "gate_one_status", limit: 255, default: "incomplete", null: false
    t.string "gate_two_status", limit: 255, default: "incomplete", null: false
    t.string "legacy_external_id"
    t.boolean "legacy_import", default: false, null: false
    t.datetime "legacy_imported_at"
    t.json "legacy_metadata", default: {}, null: false
    t.string "legacy_source"
    t.json "linked_commit_shas"
    t.json "linked_pr_urls"
    t.boolean "needs_structuring", default: false, null: false
    t.string "priority"
    t.text "problem_description"
    t.text "reproduction_steps"
    t.text "root_cause"
    t.string "severity", limit: 255
    t.text "structured_summary"
    t.json "suggested_primitives"
    t.datetime "updated_at", null: false
    t.text "verification_steps"
    t.datetime "verified_at"
    t.uuid "verified_by_id"
    t.index ["account_id", "category"], name: "index_card_resolution_records_on_account_id_and_category"
    t.index ["account_id", "domain"], name: "index_card_resolution_records_on_account_id_and_domain"
    t.index ["account_id", "gate_one_status"], name: "idx_on_account_id_gate_one_status_be337b4a03"
    t.index ["account_id", "gate_two_status"], name: "idx_on_account_id_gate_two_status_1d133d3b82"
    t.index ["account_id", "legacy_import"], name: "index_card_resolution_records_on_account_id_and_legacy_import"
    t.index ["account_id", "legacy_source", "legacy_external_id"], name: "idx_on_account_id_legacy_source_legacy_external_id_2bdb0ae1de", unique: true, where: "((legacy_source IS NOT NULL) AND (legacy_external_id IS NOT NULL))"
    t.index ["account_id", "needs_structuring"], name: "idx_on_account_id_needs_structuring_93d1adaa31"
    t.index ["account_id", "priority"], name: "index_card_resolution_records_on_account_id_and_priority"
    t.index ["account_id"], name: "index_card_resolution_records_on_account_id"
    t.index ["card_id"], name: "index_card_resolution_records_on_card_id", unique: true
    t.index ["verified_by_id"], name: "index_card_resolution_records_on_verified_by_id"
  end

  create_table "cards", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.uuid "column_id"
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.date "due_on"
    t.datetime "last_active_at", null: false
    t.bigint "number", null: false
    t.string "status", limit: 255, default: "drafted", null: false
    t.string "title", limit: 255
    t.datetime "updated_at", null: false
    t.index ["account_id", "last_active_at", "status"], name: "index_cards_on_account_id_and_last_active_at_and_status"
    t.index ["account_id", "number"], name: "index_cards_on_account_id_and_number", unique: true
    t.index ["board_id"], name: "index_cards_on_board_id"
    t.index ["column_id"], name: "index_cards_on_column_id"
  end

  create_table "closers_filters", id: false, force: :cascade do |t|
    t.uuid "closer_id", null: false
    t.uuid "filter_id", null: false
    t.index ["closer_id"], name: "index_closers_filters_on_closer_id"
    t.index ["filter_id"], name: "index_closers_filters_on_filter_id"
  end

  create_table "closures", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["account_id"], name: "index_closures_on_account_id"
    t.index ["card_id", "created_at"], name: "index_closures_on_card_id_and_created_at"
    t.index ["card_id"], name: "index_closures_on_card_id", unique: true
    t.index ["user_id"], name: "index_closures_on_user_id"
  end

  create_table "columns", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.string "color", limit: 255, null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 255, null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_columns_on_account_id"
    t.index ["board_id", "position"], name: "index_columns_on_board_id_and_position"
    t.index ["board_id"], name: "index_columns_on_board_id"
  end

  create_table "comments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_comments_on_account_id"
    t.index ["card_id"], name: "index_comments_on_card_id"
  end

  create_table "creators_filters", id: false, force: :cascade do |t|
    t.uuid "creator_id", null: false
    t.uuid "filter_id", null: false
    t.index ["creator_id"], name: "index_creators_filters_on_creator_id"
    t.index ["filter_id"], name: "index_creators_filters_on_filter_id"
  end

  create_table "entropies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.bigint "auto_postpone_period", default: 2592000, null: false
    t.uuid "container_id", null: false
    t.string "container_type", limit: 255, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_entropies_on_account_id"
    t.index ["container_type", "container_id", "auto_postpone_period"], name: "idx_on_container_type_container_id_auto_postpone_pe_3d79b50517"
    t.index ["container_type", "container_id"], name: "index_entropy_configurations_on_container", unique: true
  end

  create_table "events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "action", limit: 255, null: false
    t.uuid "board_id", null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.uuid "eventable_id", null: false
    t.string "eventable_type", limit: 255, null: false
    t.json "particulars", default: {}
    t.datetime "updated_at", null: false
    t.index ["account_id", "action"], name: "index_events_on_account_id_and_action"
    t.index ["board_id", "action", "created_at"], name: "index_events_on_board_id_and_action_and_created_at"
    t.index ["board_id"], name: "index_events_on_board_id"
    t.index ["creator_id"], name: "index_events_on_creator_id"
    t.index ["eventable_type", "eventable_id"], name: "index_events_on_eventable"
  end

  create_table "exports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "status", limit: 255, default: "pending", null: false
    t.string "type", limit: 255
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_exports_on_account_id"
    t.index ["type"], name: "index_exports_on_type"
    t.index ["user_id"], name: "index_exports_on_user_id"
  end

  create_table "filters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.json "fields", default: {}, null: false
    t.string "params_digest", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_filters_on_account_id"
    t.index ["creator_id", "params_digest"], name: "index_filters_on_creator_id_and_params_digest", unique: true
  end

  create_table "filters_tags", id: false, force: :cascade do |t|
    t.uuid "filter_id", null: false
    t.uuid "tag_id", null: false
    t.index ["filter_id"], name: "index_filters_tags_on_filter_id"
    t.index ["tag_id"], name: "index_filters_tags_on_tag_id"
  end

  create_table "github_webhook_deliveries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.string "delivery_id", limit: 255, null: false
    t.text "error_message"
    t.string "event", limit: 255, null: false
    t.integer "linked_code_references_count", default: 0, null: false
    t.json "payload", default: {}, null: false
    t.string "payload_sha256", limit: 255, null: false
    t.datetime "processed_at"
    t.string "status", limit: 255, default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_github_webhook_deliveries_on_account_id_and_created_at"
    t.index ["account_id", "delivery_id"], name: "index_github_webhook_deliveries_on_account_id_and_delivery_id", unique: true
    t.index ["account_id", "status"], name: "index_github_webhook_deliveries_on_account_id_and_status"
    t.index ["account_id"], name: "index_github_webhook_deliveries_on_account_id"
  end

  create_table "identities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", limit: 255, null: false
    t.string "password_digest"
    t.boolean "staff", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_identities_on_email_address", unique: true
  end

  create_table "identity_access_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.uuid "identity_id", null: false
    t.string "permission", limit: 255
    t.string "token", limit: 255
    t.datetime "updated_at", null: false
    t.index ["identity_id"], name: "index_access_token_on_identity_id"
  end

  create_table "legacy_imports_asana_imports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "created_count", default: 0, null: false
    t.uuid "creator_id", null: false
    t.text "error_message"
    t.integer "failed_count", default: 0, null: false
    t.integer "needs_structuring_count", default: 0, null: false
    t.integer "skipped_count", default: 0, null: false
    t.datetime "started_at"
    t.string "status", limit: 255, default: "pending", null: false
    t.integer "total_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "idx_on_account_id_created_at_cf4a023b65"
    t.index ["account_id", "status"], name: "index_legacy_imports_asana_imports_on_account_id_and_status"
    t.index ["account_id"], name: "index_legacy_imports_asana_imports_on_account_id"
    t.index ["board_id"], name: "index_legacy_imports_asana_imports_on_board_id"
    t.index ["creator_id"], name: "index_legacy_imports_asana_imports_on_creator_id"
  end

  create_table "magic_links", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", limit: 255, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.uuid "identity_id"
    t.integer "purpose", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_magic_links_on_code", unique: true
    t.index ["expires_at"], name: "index_magic_links_on_expires_at"
    t.index ["identity_id"], name: "index_magic_links_on_identity_id"
  end

  create_table "mentions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "mentionee_id", null: false
    t.uuid "mentioner_id", null: false
    t.uuid "source_id", null: false
    t.string "source_type", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_mentions_on_account_id"
    t.index ["mentionee_id"], name: "index_mentions_on_mentionee_id"
    t.index ["mentioner_id"], name: "index_mentions_on_mentioner_id"
    t.index ["source_type", "source_id"], name: "index_mentions_on_source"
  end

  create_table "notification_bundles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.datetime "starts_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_notification_bundles_on_account_id"
    t.index ["ends_at", "status"], name: "index_notification_bundles_on_ends_at_and_status"
    t.index ["user_id", "starts_at", "ends_at"], name: "idx_on_user_id_starts_at_ends_at_7eae5d3ac5"
    t.index ["user_id", "status"], name: "index_notification_bundles_on_user_id_and_status"
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id"
    t.datetime "read_at"
    t.uuid "source_id", null: false
    t.string "source_type", limit: 255, null: false
    t.integer "unread_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_notifications_on_account_id"
    t.index ["creator_id"], name: "index_notifications_on_creator_id"
    t.index ["source_type", "source_id"], name: "index_notifications_on_source"
    t.index ["user_id", "card_id"], name: "index_notifications_on_user_id_and_card_id", unique: true
    t.index ["user_id", "read_at", "updated_at"], name: "index_notifications_on_user_id_and_read_at_and_updated_at", order: { read_at: :desc, updated_at: :desc }
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "pins", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_pins_on_account_id"
    t.index ["card_id", "user_id"], name: "index_pins_on_card_id_and_user_id", unique: true
    t.index ["card_id"], name: "index_pins_on_card_id"
    t.index ["user_id"], name: "index_pins_on_user_id"
  end

  create_table "push_subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "auth_key", limit: 255
    t.datetime "created_at", null: false
    t.text "endpoint"
    t.string "p256dh_key", limit: 255
    t.datetime "updated_at", null: false
    t.string "user_agent", limit: 4096
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_push_subscriptions_on_account_id"
    t.index ["user_id", "endpoint"], name: "index_push_subscriptions_on_user_id_and_endpoint", unique: true
  end

  create_table "reactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "content", limit: 16, null: false
    t.datetime "created_at", null: false
    t.uuid "reactable_id", null: false
    t.string "reactable_type", limit: 255, null: false
    t.uuid "reacter_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_reactions_on_account_id"
    t.index ["reactable_type", "reactable_id"], name: "index_reactions_on_reactable_type_and_reactable_id"
    t.index ["reacter_id"], name: "index_reactions_on_reacter_id"
  end

  create_table "search_queries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.string "terms", limit: 2000, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_search_queries_on_account_id"
    t.index ["user_id", "terms"], name: "index_search_queries_on_user_id_and_terms"
    t.index ["user_id", "updated_at"], name: "index_search_queries_on_user_id_and_updated_at", unique: true
    t.index ["user_id"], name: "index_search_queries_on_user_id"
  end

  create_table "search_records_0", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_0_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_0_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_1", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_1_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_1_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_10", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_10_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_10_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_11", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_11_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_11_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_12", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_12_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_12_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_13", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_13_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_13_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_14", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_14_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_14_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_15", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_15_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_15_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_2", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_2_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_2_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_3", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_3_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_3_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_4", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_4_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_4_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_5", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_5_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_5_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_6", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_6_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_6_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_7", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_7_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_7_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_8", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_8_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_8_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "search_records_9", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "account_key", limit: 255, default: "", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_9_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_9_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "identity_id", null: false
    t.string "ip_address", limit: 255
    t.datetime "updated_at", null: false
    t.string "user_agent", limit: 4096
    t.index ["identity_id"], name: "index_sessions_on_identity_id"
  end

  create_table "steps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.boolean "completed", default: false, null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_steps_on_account_id"
    t.index ["card_id", "completed"], name: "index_steps_on_card_id_and_completed"
    t.index ["card_id"], name: "index_steps_on_card_id"
  end

  create_table "storage_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "blob_id"
    t.uuid "board_id"
    t.datetime "created_at", null: false
    t.bigint "delta", null: false
    t.string "operation", limit: 255, null: false
    t.uuid "recordable_id"
    t.string "recordable_type", limit: 255
    t.string "request_id", limit: 255
    t.uuid "user_id"
    t.index ["account_id"], name: "index_storage_entries_on_account_id"
    t.index ["blob_id"], name: "index_storage_entries_on_blob_id"
    t.index ["board_id"], name: "index_storage_entries_on_board_id"
    t.index ["recordable_type", "recordable_id"], name: "index_storage_entries_on_recordable"
    t.index ["request_id"], name: "index_storage_entries_on_request_id"
    t.index ["user_id"], name: "index_storage_entries_on_user_id"
  end

  create_table "storage_totals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "bytes_stored", default: 0, null: false
    t.datetime "created_at", null: false
    t.uuid "last_entry_id"
    t.uuid "owner_id", null: false
    t.string "owner_type", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_storage_totals_on_owner_type_and_owner_id", unique: true
  end

  create_table "taggings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.uuid "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_taggings_on_account_id"
    t.index ["card_id", "tag_id"], name: "index_taggings_on_card_id_and_tag_id", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
  end

  create_table "tags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.string "title", limit: 255
    t.datetime "updated_at", null: false
    t.index ["account_id", "title"], name: "index_tags_on_account_id_and_title", unique: true
  end

  create_table "training_example_exports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "example_count", default: 0, null: false
    t.string "filename", limit: 255, null: false
    t.datetime "started_at"
    t.string "status", limit: 255, default: "pending", null: false
    t.json "training_example_ids", default: [], null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id", "created_at"], name: "index_training_example_exports_on_account_id_and_created_at"
    t.index ["account_id", "status"], name: "index_training_example_exports_on_account_id_and_status"
    t.index ["account_id"], name: "index_training_example_exports_on_account_id"
    t.index ["user_id"], name: "index_training_example_exports_on_user_id"
  end

  create_table "training_examples", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "exported_at"
    t.json "input_context", null: false
    t.json "metadata", null: false
    t.text "problem_summary"
    t.text "resolution_summary"
    t.text "review_notes"
    t.datetime "reviewed_at"
    t.uuid "reviewed_by_id"
    t.text "root_cause"
    t.string "status", limit: 255, default: "draft", null: false
    t.uuid "training_example_export_id"
    t.datetime "updated_at", null: false
    t.text "verification_steps"
    t.index ["account_id", "status"], name: "index_training_examples_on_account_id_and_status"
    t.index ["account_id"], name: "index_training_examples_on_account_id"
    t.index ["card_id", "status"], name: "index_training_examples_on_card_id_and_status"
    t.index ["card_id"], name: "index_training_examples_on_card_id"
    t.index ["reviewed_by_id"], name: "index_training_examples_on_reviewed_by_id"
    t.index ["training_example_export_id"], name: "index_training_examples_on_training_example_export_id"
  end

  create_table "user_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.integer "bundle_email_frequency", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "timezone_name", limit: 255
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_user_settings_on_account_id"
    t.index ["user_id", "bundle_email_frequency"], name: "index_user_settings_on_user_id_and_bundle_email_frequency"
    t.index ["user_id"], name: "index_user_settings_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.boolean "active", default: true, null: false
    t.string "cactus_role", default: "reporter", null: false
    t.datetime "created_at", null: false
    t.uuid "identity_id"
    t.string "name", limit: 255, null: false
    t.string "role", limit: 255, default: "member", null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["account_id", "cactus_role"], name: "index_users_on_account_id_and_cactus_role"
    t.index ["account_id", "identity_id"], name: "index_users_on_account_id_and_identity_id", unique: true
    t.index ["account_id", "role"], name: "index_users_on_account_id_and_role"
    t.index ["identity_id"], name: "index_users_on_identity_id"
  end

  create_table "watches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.boolean "watching", default: true, null: false
    t.index ["account_id"], name: "index_watches_on_account_id"
    t.index ["card_id"], name: "index_watches_on_card_id"
    t.index ["user_id", "card_id"], name: "index_watches_on_user_id_and_card_id"
    t.index ["user_id"], name: "index_watches_on_user_id"
  end

  create_table "webhook_delinquency_trackers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.integer "consecutive_failures_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "first_failure_at"
    t.datetime "updated_at", null: false
    t.uuid "webhook_id", null: false
    t.index ["account_id"], name: "index_webhook_delinquency_trackers_on_account_id"
    t.index ["webhook_id"], name: "index_webhook_delinquency_trackers_on_webhook_id"
  end

  create_table "webhook_deliveries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "event_id", null: false
    t.text "request"
    t.text "response"
    t.string "state", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.uuid "webhook_id", null: false
    t.index ["account_id"], name: "index_webhook_deliveries_on_account_id"
    t.index ["created_at"], name: "index_webhook_deliveries_on_created_at"
    t.index ["event_id"], name: "index_webhook_deliveries_on_event_id"
    t.index ["webhook_id"], name: "index_webhook_deliveries_on_webhook_id"
  end

  create_table "webhooks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.boolean "active", default: true, null: false
    t.uuid "board_id", null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 255
    t.string "signing_secret", limit: 255, null: false
    t.text "subscribed_actions"
    t.datetime "updated_at", null: false
    t.text "url", null: false
    t.index ["account_id"], name: "index_webhooks_on_account_id"
    t.index ["board_id", "subscribed_actions"], name: "index_webhooks_on_board_id_and_subscribed_actions"
  end
end
