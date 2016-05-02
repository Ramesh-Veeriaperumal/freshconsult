class CreateScheduleConfigurations < ActiveRecord::Migration
  shard :all
  
  def up
    create_table :schedule_configurations,  :force => true do |t|
      t.integer     :account_id,          :limit => 8
      t.integer     :scheduled_task_id,   :limit => 8
      t.integer     :notification_type,   :limit => 2
      t.text        :config_data,         :limit => 16777215
      t.text        :description,         :limit => 16777215
      t.timestamps
    end
    add_index :schedule_configurations, [:account_id, :scheduled_task_id], :name => "index_schedule_configuration_on_account_id_and_scheduled_task_id"
  end

  def down
    drop_table :schedule_configurations
  end
end
