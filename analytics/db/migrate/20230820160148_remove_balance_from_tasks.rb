class RemoveBalanceFromTasks < ActiveRecord::Migration[7.0]
  def change
    remove_column :tasks, :balance
  end
end
