class CreateAuditLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :audit_logs do |t|
      t.uuid :public_id, default: "gen_random_uuid()", null: false
      t.references :account, type: :uuid, null: true, index: true, foreign_key: { to_table: :accounts, primary_key: :public_id }
      t.references :task, type: :uuid, null: true, index: true, foreign_key: { to_table: :tasks, primary_key: :public_id }
      t.integer :amount
      t.string :event_type

      t.timestamps
    end
    add_index :audit_logs, :public_id, unique: true
  end
end
