class DropFreshfoneCallsMeta < ActiveRecord::Migration
  shard :all

  def self.up
    Lhm.change_table :freshfone_calls_meta, :atomic_switch => true do |m|
      m.remove_index [:account_id, :call_id, :group_id], 'index_ff_calls_on_account_id_call_id_group_id'
    end
    drop_table :freshfone_calls_meta
  end

  def self.down
    execute(
      "CREATE TABLE `freshfone_calls_meta` (
      `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
      `account_id` bigint(20) DEFAULT NULL,
      `call_id` bigint(20) DEFAULT NULL,
      `group_id` bigint(20) DEFAULT NULL,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
       UNIQUE KEY `index_freshfone_calls_meta_on_id_and_account_id` (`id`,`account_id`),
       KEY `index_ff_calls_on_account_id_call_id_group_id` (`account_id`,`call_id`,`group_id`)
      ) ENGINE=InnoDB AUTO_INCREMENT=575412 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci 
      /*!50100 PARTITION BY HASH (account_id) PARTITIONS 128 */;"
    )
  end
end
