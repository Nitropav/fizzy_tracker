class AddAsyncStateToTrainingExampleExports < ActiveRecord::Migration[8.1]
  def change
    change_column_default :training_example_exports, :status, from: "completed", to: "pending"
    change_column_null :training_example_exports, :completed_at, true

    add_column :training_example_exports, :started_at, :datetime
    add_column :training_example_exports, :error_message, :text
  end
end
