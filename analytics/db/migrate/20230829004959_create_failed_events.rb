class CreateFailedEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :failed_events do |t|
      t.string :topic
      t.uuid :event_id
      t.integer :event_version
      t.datetime :event_time
      t.string :producer
      t.string :event_name
      t.text :error_message
      t.jsonb :raw

      t.timestamps
    end
  end
end
