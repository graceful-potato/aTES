class CreateTasks < ActiveRecord::Migration[7.0]
  def change
    create_table :tasks do |t|
      t.uuid :public_id, default: "gen_random_uuid()", index: { unique: true }
      t.text :description
      t.datetime :completed_at
      t.references :assignee, type: :uuid, index: true, foreign_key: { to_table: :accounts, primary_key: :public_id }

      t.timestamps
    end
  end
end
