class ChangeColumnAccessibleIdAdminUserAccess < ActiveRecord::Migration
  shard :all
  def self.up
    execute <<-SQL
      ALTER TABLE admin_user_accesses CHANGE `accessible_id` `accessible_id` bigint(20) unsigned DEFAULT NULL
    SQL
  end

  def self.down
    execute <<-SQL
      ALTER TABLE admin_user_accesses CHANGE `accessible_id` `accessible_id` int(11) DEFAULT NULL
    SQL
  end
end
