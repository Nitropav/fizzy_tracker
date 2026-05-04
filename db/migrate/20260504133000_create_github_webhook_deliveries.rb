class CreateGithubWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :github_webhook_deliveries, id: :uuid do |t|
      t.uuid :account_id, null: false

      t.string :delivery_id, null: false
      t.string :event, null: false
      t.string :status, null: false, default: "pending"
      t.string :payload_sha256, null: false
      t.integer :linked_code_references_count, null: false, default: 0
      t.text :error_message
      t.datetime :processed_at

      t.timestamps

      t.index :account_id
      t.index [ :account_id, :delivery_id ], unique: true
      t.index [ :account_id, :status ]
      t.index [ :account_id, :created_at ]
    end
  end
end
