class CreateLegacyImportsAsanaImports < ActiveRecord::Migration[8.1]
  def change
    create_table :legacy_imports_asana_imports, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :board_id, null: false
      t.uuid :creator_id, null: false

      t.string :status, null: false, default: "pending"
      t.integer :total_count, null: false, default: 0
      t.integer :created_count, null: false, default: 0
      t.integer :skipped_count, null: false, default: 0
      t.integer :needs_structuring_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps

      t.index :account_id
      t.index :board_id
      t.index :creator_id
      t.index [ :account_id, :status ]
      t.index [ :account_id, :created_at ]
    end
  end
end
