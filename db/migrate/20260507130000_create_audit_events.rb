class CreateAuditEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_events, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: true, foreign_key: true
      t.string :action, null: false
      t.references :auditable, type: :uuid, polymorphic: true, null: true, index: true
      t.json :metadata, null: false, default: {}
      t.string :request_id
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    add_index :audit_events, [ :account_id, :created_at ]
    add_index :audit_events, [ :account_id, :action ]
  end
end
