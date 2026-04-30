class CreateCardCodeLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :card_code_links, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :card_id, null: false

      t.string :provider, null: false
      t.string :external_type, null: false
      t.string :external_id, null: false
      t.string :repository
      t.string :sha
      t.text :title
      t.text :url
      t.json :metadata, null: false

      t.timestamps

      t.index :account_id
      t.index :card_id
      t.index [ :account_id, :provider, :external_type, :external_id, :card_id ], unique: true, name: "index_card_code_links_on_unique_external_reference"
      t.index [ :account_id, :provider, :repository ]
      t.index [ :account_id, :sha ]
    end
  end
end
