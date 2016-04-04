class AddCallerTypeToFreshfoneCaller < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :freshfone_callers, :atomic_switch => true do |m|
      m.add_column :caller_type, "tinyint(2) DEFAULT 0"
      m.add_unique_index [:id, :account_id], "index_freshfone_callers_on_id_and_account_id"
      m.ddl("ALTER TABLE %s DROP PRIMARY KEY" % m.name)
      m.ddl("alter table %s partition by hash(account_id) partitions 128" % m.name)
    end    
    execute("UPDATE freshfone_callers fc 
      inner join freshfone_blacklist_numbers bn on 
      (bn.`account_id` = fc.`account_id` and CONCAT('+', bn.`number`) = fc.`number`) set fc.`caller_type` = 1 ")
  end

  def self.down
    Lhm.change_table :freshfone_callers, :atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s REMOVE PARTITIONING" % m.name)
      m.ddl("ALTER TABLE %s ADD PRIMARY KEY(id)" % m.name)
      m.ddl("ALTER TABLE %s DROP INDEX `index_freshfone_callers_on_id_and_account_id`" %m.name)
      m.remove_column :caller_type
    end
  end
end
