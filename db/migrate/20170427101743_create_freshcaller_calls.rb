class CreateFreshcallerCalls < ActiveRecord::Migration
  shard :all
  def up
    execute("CREATE TABLE `freshcaller_calls` (
      `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
      `account_id` bigint(20) DEFAULT NULL,
      `fc_call_id` bigint(20) NOT NULL UNIQUE,
      `recording_status` tinyint(4) DEFAULT NULL,
      `notable_id` bigint(20) DEFAULT NULL,
      `notable_type` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
      `created_at` datetime NOT NULL,
      `updated_at` datetime NOT NULL,
      PRIMARY KEY (`id`),
      KEY `index_freshcaller_calls_on_account_id_and_fc_call_id` (`account_id`,`fc_call_id`)
    ) ENGINE=InnoDB AUTO_INCREMENT=239 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;")
  end

  def down
    drop_table :freshcaller_calls
  end
end
