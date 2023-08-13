class AddFeeAndRewardFieldsToTask < ActiveRecord::Migration[7.0]
  def change
    add_column :tasks, :fee, :integer
    add_column :tasks, :reward, :integer
  end
end
