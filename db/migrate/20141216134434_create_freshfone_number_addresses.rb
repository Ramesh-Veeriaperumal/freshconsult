class CreateFreshfoneNumberAddresses < ActiveRecord::Migration
  shard :all
  def self.up
    execute(
      "CREATE TABLE `freshfone_number_address` (
      `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
      `account_id` bigint(20) DEFAULT NULL,
      `freshfone_account_id` bigint(20) DEFAULT NULL,
      `address_sid` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
      `friendly_name` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
      `business_name` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
      `address` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
      `city` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
      `state` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
      `postal_code` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
      `country` varchar(5) CHARACTER SET latin1 DEFAULT NULL,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      UNIQUE KEY `index_freshfone_number_address_on_id_and_account_id` (`id`,`account_id`),
      KEY `index_freshfone_number_address_on_account_id_and_country` (`account_id`,`country`)
      ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
      /*!50100 PARTITION BY HASH (account_id)
        PARTITIONS 128 */;"
    )
  end

  def self.down
    drop_table :freshfone_number_address
  end
end
