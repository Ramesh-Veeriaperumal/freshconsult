class CreateTableUserAccesses < ActiveRecord::Migration
  shard :all
  def self.up
    execute("
      CREATE TABLE `user_accesses` (
      `user_id` bigint(20) unsigned NOT NULL,
      `access_id` bigint(20) unsigned NOT NULL,
      `account_id` bigint(20) unsigned NOT NULL,
      KEY `index_user_accesses_on_account_id` (`account_id`),
      KEY `index_user_accesses_on_access_id` (`access_id`),
      KEY `index_user_accesses_on_user_id` (`user_id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;")
  end

  def self.down
    drop_table :user_accesses
  end
end
