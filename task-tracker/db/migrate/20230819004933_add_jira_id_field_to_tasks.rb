class AddJiraIdFieldToTasks < ActiveRecord::Migration[7.0]
  def change
    add_column :tasks, :jira_id, :string
  end
end
