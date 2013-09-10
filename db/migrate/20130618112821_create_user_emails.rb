class CreateUserEmails < ActiveRecord::Migration
  shard :none
  def self.up
    execute("CREATE TABLE `user_emails` (
    `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
    `user_id` bigint(20) unsigned NOT NULL,
    `email` varchar(255) DEFAULT NULL,
    `account_id` bigint(20) unsigned NOT NULL,
    `perishable_token` varchar(255) DEFAULT NULL,
    `verified` tinyint(1) DEFAULT '0',
    `primary_role` tinyint(1) DEFAULT '0',
    `created_at` datetime DEFAULT NULL,
    `updated_at` datetime DEFAULT NULL,
    UNIQUE KEY `index_user_emails_on_account_id_and_email` (`account_id`,`email`),
    KEY `index_user_emails_on_user_id_and_account_id` (`user_id`, `account_id`),
    KEY `user_emails_email` (`email`),
    KEY `user_emails_id` (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
    PARTITION BY HASH(account_id)
    PARTITIONS 128;")
  end

  def self.down
    drop_table :user_emails
  end
end
