class AddNewFreshfoneCallsMeta < ActiveRecord::Migration
  shard :all
  
  def self.up
    execute(
      "CREATE TABLE `freshfone_calls_meta` (
      `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
      `account_id` bigint(20) DEFAULT NULL,
      `call_id` bigint(20) DEFAULT NULL,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      `meta_info` text COLLATE utf8_unicode_ci,
      `device_type` int(12) DEFAULT NULL,
      UNIQUE KEY `index_freshfone_calls_meta_on_id_and_account_id` (`id`,`account_id`),
      KEY `index_ff_calls_meta_on_account_id_device_type` (`account_id`,`device_type`),
      KEY `index_ff_calls_meta_on_account_id_call_id` (`account_id`,`call_id`)
      ) ENGINE=InnoDB AUTO_INCREMENT=575412 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci 
      /*!50100 PARTITION BY HASH (account_id) PARTITIONS 128 */;"
    )
  end

  def self.down
    drop_table :freshfone_calls_meta
  end
end
