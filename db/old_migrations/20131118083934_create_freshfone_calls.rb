class CreateFreshfoneCalls < ActiveRecord::Migration
	shard :none
	def self.up
		execute("CREATE TABLE `freshfone_calls` (
		`id` bigint(20) NOT NULL AUTO_INCREMENT,
		`account_id` bigint(20) NOT NULL,
		`freshfone_number_id` bigint(20) NOT NULL,
		`user_id` bigint(20) DEFAULT NULL,
		`customer_id` bigint(20) DEFAULT NULL,
		`call_sid` varchar(50) COLLATE utf8_unicode_ci DEFAULT NULL,
		`dial_call_sid` varchar(50) COLLATE utf8_unicode_ci DEFAULT NULL,
		`call_status` int(11) DEFAULT '0',
		`call_type` int(11) DEFAULT '0',
		`call_duration` int(11) DEFAULT NULL,
		`recording_url` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
		`customer_number` varchar(50) COLLATE utf8_unicode_ci DEFAULT NULL,
		`customer_data` text COLLATE utf8_unicode_ci,
		`call_cost` float DEFAULT NULL,
		`currency` varchar(20) COLLATE utf8_unicode_ci DEFAULT 'USD',
		`ancestry` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
		`children_count` int(11) DEFAULT '0',
		`notable_id` bigint(20) DEFAULT NULL,
		`notable_type` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
		`created_at` datetime DEFAULT NULL,
		`updated_at` datetime DEFAULT NULL,
		UNIQUE KEY `index_freshfone_calls_on_id_and_account_id` (`id`,`account_id`),
		KEY `index_freshfone_calls_on_account_id_and_ancestry` (`account_id`,`ancestry`(12)),
		KEY `index_freshfone_calls_on_account_id_and_call_sid` (`account_id`,`call_sid`),
		KEY `index_freshfone_calls_on_account_id_and_call_status_and_user` (`account_id`,`call_status`,`user_id`),
		KEY `index_freshfone_calls_on_account_id_and_customer_number` (`account_id`,`customer_number`(16)),
		KEY `index_freshfone_calls_on_account_id_and_dial_call_sid` (`account_id`,`dial_call_sid`),
		KEY `index_ff_calls_on_account_ff_number_and_created` (`account_id`,`freshfone_number_id`,`created_at`),
		KEY `index_freshfone_calls_on_account_id_and_freshfone_number_id` (`account_id`,`freshfone_number_id`),
		KEY `index_ff_calls_on_account_user_ancestry_and_created_at` (`account_id`,`user_id`,`created_at`,`ancestry`)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
		/*!50100 PARTITION BY HASH (account_id) PARTITIONS 128 */;");
	end

	def self.down
		drop_table :freshfone_calls
	end
end