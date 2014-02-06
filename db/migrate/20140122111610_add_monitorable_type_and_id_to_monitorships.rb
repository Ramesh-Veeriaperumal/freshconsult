class AddMonitorableTypeAndIdToMonitorships < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :monitorships, :atomic_switch => true do |m|
      m.add_column :monitorable_type, "varchar(255) DEFAULT NULL"
      m.ddl("ALTER TABLE %s CHANGE topic_id monitorable_id bigint unsigned" % m.name)
      m.ddl("ALTER TABLE %s ADD INDEX `complete_monitor_index` (`account_id`, `user_id`, `monitorable_id`, `monitorable_type`)" % m.name)
    end
    execute("UPDATE monitorships SET monitorable_type = 'Topic'")
  end

  def self.down
    execute("DELETE FROM monitorships where monitorable_type='Forum'")
    Lhm.change_table :monitorships, :atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s DROP INDEX `complete_monitor_index`" % m.name)
      m.ddl("ALTER TABLE %s CHANGE monitorable_id topic_id bigint unsigned" % m.name)
      m.remove_column :monitorable_type
    end
  end
end
