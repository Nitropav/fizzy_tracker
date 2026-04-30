class CreateAiRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_runs, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :card_id
      t.uuid :user_id

      t.string :run_type, null: false
      t.string :status, default: "pending", null: false
      t.json :input_context, null: false
      t.json :output, null: false
      t.json :metadata, null: false
      t.datetime :completed_at

      t.timestamps

      t.index :account_id
      t.index :card_id
      t.index :user_id
      t.index [ :account_id, :run_type, :status ]
      t.index [ :card_id, :run_type, :created_at ]
    end
  end
end
