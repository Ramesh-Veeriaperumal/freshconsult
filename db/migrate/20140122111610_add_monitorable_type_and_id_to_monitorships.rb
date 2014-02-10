class AddMonitorableTypeAndIdToMonitorships < ActiveRecord::Migration
  shard :all
  def self.up
    add_column :monitorships, :monitorable_type, :string
    execute("ALTER TABLE monitorships CHANGE topic_id monitorable_id bigint(20) DEFAULT NULL")
    execute("ALTER TABLE monitorships ADD INDEX `complete_monitor_index` (`account_id`, `user_id`, `monitorable_id`, `monitorable_type`)")
    execute("UPDATE monitorships SET monitorable_type = 'Topic'")
  end

  def self.down
    execute("DELETE FROM monitorships where monitorable_type='Forum'")
    execute("ALTER TABLE monitorships DROP INDEX `complete_monitor_index`")
    execute("ALTER TABLE monitorships CHANGE monitorable_id topic_id bigint(20) DEFAULT NULL")
    remove_column :monitorships, :monitorable_type
  end
end
