class AddCactusRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :cactus_role, :string, null: false, default: "reporter"
    add_index :users, [ :account_id, :cactus_role ]
  end
end
