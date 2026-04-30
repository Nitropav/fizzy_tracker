class CreateTrainingExamples < ActiveRecord::Migration[8.1]
  def change
    create_table :training_examples, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :card_id, null: false
      t.uuid :reviewed_by_id

      t.string :status, default: "draft", null: false
      t.json :input_context, null: false
      t.text :problem_summary
      t.text :root_cause
      t.text :resolution_summary
      t.text :verification_steps
      t.json :metadata, null: false
      t.text :review_notes
      t.datetime :reviewed_at
      t.datetime :exported_at

      t.timestamps

      t.index :account_id
      t.index :card_id
      t.index :reviewed_by_id
      t.index [ :account_id, :status ]
      t.index [ :card_id, :status ]
    end
  end
end
