class CreateCardResolutionRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :card_resolution_records, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :card_id, null: false

      t.string :gate_one_status, default: "incomplete", null: false
      t.string :gate_two_status, default: "incomplete", null: false

      t.text :problem_description
      t.text :reproduction_steps
      t.text :expected_behavior
      t.text :actual_behavior
      t.text :environment_context
      t.text :structured_summary

      t.string :category
      t.string :domain
      t.string :severity
      t.json :suggested_primitives

      t.text :root_cause
      t.text :fix_summary
      t.text :verification_steps
      t.json :linked_commit_shas
      t.json :linked_pr_urls
      t.uuid :verified_by_id
      t.datetime :verified_at

      t.timestamps

      t.index :account_id
      t.index :card_id, unique: true
      t.index [ :account_id, :gate_one_status ]
      t.index [ :account_id, :gate_two_status ]
      t.index [ :account_id, :category ]
      t.index [ :account_id, :domain ]
      t.index :verified_by_id
    end
  end
end
