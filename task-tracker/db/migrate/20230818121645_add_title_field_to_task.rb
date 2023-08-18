class AddTitleFieldToTask < ActiveRecord::Migration[7.0]
  def change
    add_column :tasks, :title, :string
  end
end
