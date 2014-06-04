class CreateHelpdeskAccesses < ActiveRecord::Migration
  shard :all
  def self.up
   execute(" CREATE TABLE `helpdesk_accesses` (
      `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
      `accessible_type` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
      `accessible_id` bigint(20) DEFAULT NULL,
      `account_id` bigint(20) DEFAULT NULL,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      `access_type` int(11) DEFAULT 0,
      PRIMARY KEY (`id`),
      KEY `index_helpdesk_accesses_on_accessibles`(`account_id`,`accessible_type`,`accessible_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;")
  end

  def self.down
    drop_table :helpdesk_accesses
  end
end
