class CreateTrainingExampleExports < ActiveRecord::Migration[8.1]
  def change
    create_table :training_example_exports, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :user_id, null: false

      t.string :status, null: false, default: "completed"
      t.string :filename, null: false
      t.integer :example_count, null: false, default: 0
      t.json :training_example_ids, null: false, default: []
      t.datetime :completed_at, null: false

      t.timestamps

      t.index :account_id
      t.index :user_id
      t.index [ :account_id, :created_at ]
      t.index [ :account_id, :status ]
    end

    add_column :training_examples, :training_example_export_id, :uuid
    add_index :training_examples, :training_example_export_id
  end
end
