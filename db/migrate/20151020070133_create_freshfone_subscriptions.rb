class CreateFreshfoneSubscriptions < ActiveRecord::Migration

  shard :all

  def up
    execute("CREATE TABLE `freshfone_subscriptions` (
      `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
      `account_id` bigint(20) NOT NULL,
      `freshfone_account_id` bigint(20),
      `inbound` text,
      `outbound` text,
      `numbers` text,
      `calls_usage` text,
      `numbers_usage` decimal(6,2) DEFAULT 0.0,
      `others_usage` decimal(10,4) DEFAULT 0.0,
      `expiry_on` datetime DEFAULT NULL,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `index_on_freshfone_subscriptions_on_freshfone_account_id` (`freshfone_account_id`),
      UNIQUE KEY `index_on_freshfone_subscriptions_on_account_id` (`account_id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;")
  end

  def down
    execute('DROP TABLE IF EXISTS `freshfone_subscriptions`')
  end
end
