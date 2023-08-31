class CreateBillingCycles < ActiveRecord::Migration[7.0]
  def change
    create_table :billing_cycles do |t|
      t.uuid :public_id
      t.references :account, type: :uuid, null: false, index: true, foreign_key: { to_table: :accounts, primary_key: :public_id }
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :status, default: 0

      t.timestamps
    end

    add_index :billing_cycles, :public_id, unique: true
  end
end
