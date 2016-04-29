class CreateScheduledTasks < ActiveRecord::Migration
  shard :all
  
  def up
    create_table :scheduled_tasks, :force => true do |t|
      t.integer     :account_id,            :limit => 8
      t.integer     :user_id,               :limit => 8
      t.integer     :schedulable_id,        :limit => 8
      t.string      :schedulable_type
      t.integer     :status,                :limit => 2, :default => 0, :null => false
      t.datetime    :next_run_at
      t.datetime    :last_run_at
      t.integer     :frequency,             :limit => 2
      t.integer     :repeat_frequency,      :limit => 2      
      t.integer     :day_of_frequency,      :limit => 2
      t.integer     :minute_of_day
      t.datetime    :start_date
      t.datetime    :end_date
      t.integer     :consecutive_failuers, :limit => 2
      t.timestamps
    end

    add_index :scheduled_tasks, [:next_run_at, :status, :account_id], :name => "index_scheduled_tasks_on_next_run_at_and_status_and_account_id"
    add_index :scheduled_tasks, [:account_id, :schedulable_type, :user_id], :name => "index_scheduled_tasks_on_account_id_schedulable_type_and_user_id"
  end

  def down
    drop_table :scheduled_tasks
  end
end
