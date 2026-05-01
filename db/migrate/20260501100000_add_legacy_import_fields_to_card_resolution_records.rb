class AddLegacyImportFieldsToCardResolutionRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :card_resolution_records, :legacy_import, :boolean, default: false, null: false
    add_column :card_resolution_records, :legacy_source, :string
    add_column :card_resolution_records, :legacy_external_id, :string
    add_column :card_resolution_records, :legacy_metadata, :json, default: {}, null: false
    add_column :card_resolution_records, :legacy_imported_at, :datetime
    add_column :card_resolution_records, :gate_one_legacy, :boolean, default: false, null: false
    add_column :card_resolution_records, :needs_structuring, :boolean, default: false, null: false

    add_index :card_resolution_records, [ :account_id, :legacy_import ]
    add_index :card_resolution_records,
      [ :account_id, :legacy_source, :legacy_external_id ],
      unique: true,
      where: "legacy_source IS NOT NULL AND legacy_external_id IS NOT NULL"
    add_index :card_resolution_records, [ :account_id, :needs_structuring ]
  end
end
