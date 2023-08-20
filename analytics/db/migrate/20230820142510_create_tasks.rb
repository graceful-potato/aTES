class CreateTasks < ActiveRecord::Migration[7.0]
  def change
    create_table :tasks do |t|
      t.uuid :public_id
      t.string :title
      t.string :jira_id
      t.text :description
      t.datetime :completed_at
      t.references :assignee, type: :uuid, index: true, foreign_key: { to_table: :accounts, primary_key: :public_id }
      t.integer :fee
      t.integer :reward
      t.integer :balance, null: false, default: 0

      t.timestamps
    end
    add_index :tasks, :public_id, unique: true
  end
end
