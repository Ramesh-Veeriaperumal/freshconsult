class CreateTableGroupAccesses < ActiveRecord::Migration
  shard :all
  def self.up
    execute("
      CREATE TABLE `group_accesses` (
      `group_id` bigint(20) unsigned NOT NULL,
      `access_id` bigint(20) unsigned NOT NULL,
      `account_id` bigint(20) unsigned NOT NULL,
      KEY `index_group_accesses_on_account_id` (`account_id`),
      KEY `index_group_accesses_on_access_id` (`access_id`),
      KEY `index_group_accesses_on_group_id` (`group_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;")
  end

  def self.down
    drop_table :group_accesses
  end
end
