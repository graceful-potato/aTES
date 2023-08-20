class AddBalanceToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :balance, :integer, default: 0, null: false
  end
end
