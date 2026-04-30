class AddAccountKeyToSearchRecords < ActiveRecord::Migration[8.2]
  def up
    16.times do |shard_id|
      table_name = "search_records_#{shard_id}"

      add_column table_name, :account_key, :string, null: false, default: ""
    end
  end

  def down
    16.times do |shard_id|
      table_name = "search_records_#{shard_id}"

      remove_column table_name, :account_key
    end
  end
end
