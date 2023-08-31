class CreateTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :transactions do |t|
      t.uuid :public_id, default: "gen_random_uuid()", index: { unique: true }
      t.references :billing_cycle, type: :uuid, null: false, index: true, foreign_key: { to_table: :billing_cycles, primary_key: :public_id }
      t.references :account, type: :uuid, null: false, index: true, foreign_key: { to_table: :accounts, primary_key: :public_id }
      t.references :task, type: :uuid, index: true, foreign_key: { to_table: :tasks, primary_key: :public_id }
      t.text :description
      t.integer :credit, default: 0
      t.integer :debit, default: 0
      t.integer :direction, null: false
      t.integer :kind, null: false

      t.timestamps
    end
  end
end
