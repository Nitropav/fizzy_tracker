class AddPriorityToCardResolutionRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :card_resolution_records, :priority, :string
    add_index :card_resolution_records, [ :account_id, :priority ]
  end
end
