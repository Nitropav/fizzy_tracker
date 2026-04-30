class AddPasswordDigestToIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :identities, :password_digest, :string
  end
end
