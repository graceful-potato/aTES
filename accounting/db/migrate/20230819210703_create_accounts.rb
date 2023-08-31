class CreateAccounts < ActiveRecord::Migration[7.0]
  def change
    create_table :accounts do |t|
      t.string :email
      t.string :full_name
      t.uuid :public_id
      t.string :role

      t.timestamps
    end
    add_index :accounts, :public_id, unique: true
  end
end
