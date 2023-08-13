class UpdatePublicIdIndexOnAccounts < ActiveRecord::Migration[7.0]
  def change
    remove_index :accounts, :public_id
    add_index :accounts, :public_id, unique: true
  end
end
