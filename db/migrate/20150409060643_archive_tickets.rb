class ArchiveTickets < ActiveRecord::Migration
  shard :none
  def up
  	execute("CREATE TABLE `archive_tickets` (
		    `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
	        `account_id` bigint(20) unsigned NOT NULL,
	        `requester_id` bigint(20) unsigned DEFAULT NULL,
	        `responder_id` bigint(20) DEFAULT NULL,
	        `source` int(11) DEFAULT '0',
	        `status` bigint(20) DEFAULT '1',
	        `group_id` bigint(20) DEFAULT NULL,
	        `product_id` bigint(20) DEFAULT NULL,
	        `priority` bigint(20) DEFAULT '1',
	        `ticket_type` varchar(255) DEFAULT NULL,
	        `display_id` bigint(20) DEFAULT NULL,
	        `ticket_id` bigint(20) DEFAULT NULL,
	        `created_at` datetime DEFAULT NULL,
	        `updated_at` datetime DEFAULT NULL,
	        `archive_created_at` datetime DEFAULT NULL,
	        `archive_updated_at` datetime DEFAULT NULL,
	        `subject` varchar(255) DEFAULT NULL,
	        `deleted` tinyint(1) DEFAULT '0',
	        `access_token` varchar(255) DEFAULT NULL,
	        `progress` tinyint(1) DEFAULT '0',
	        KEY `index_archive_tickets_on_account_id_and_requester_id` (`account_id`,`requester_id`),
	        KEY `index_archive_tickets_on_account_id_and_responder_id` (`account_id`,`responder_id`),
	        KEY `index_archive_tickets_on_account_id_and_created_at` (`account_id`,`created_at`),
	        KEY `index_archive_tickets_on_account_id_and_updated_at` (`account_id`,`updated_at`),
	        KEY `index_archive_tickets_on_account_id_and_archive_created_at` (`account_id`,`archive_created_at`),
	        KEY `index_archive_tickets_on_account_id_and_archive_updated_at` (`account_id`,`archive_updated_at`),
	        KEY `index_archive_tickets_on_account_id_and_group_id` (`account_id`,`group_id`),
	        KEY `index_archive_tickets_on_account_id_and_ticket_type` (`account_id`,`ticket_type`(10)),
	        KEY `index_archive_tickets_on_account_id_and_source` (`account_id`,`source`),
	        KEY `index_archive_tickets_on_account_id_and_priority` (`account_id`,`priority`),
	        KEY `index_archive_tickets_on_account_id_and_product_id` (`account_id`,`product_id`),
	        KEY `index_archive_tickets_on_account_id_and_access_token` (`account_id`,`access_token`(10)),
	        KEY `index_archive_tickets_on_account_id_and_progress` (`account_id`,`progress`),
	        UNIQUE KEY `index_archive_tickets_on_account_id_and_display_id` (`account_id`,`display_id`),
	        KEY `index_on_id` (`id`),
	        PRIMARY KEY (`account_id`,`id`)
	        )ENGINE=InnoDB DEFAULT CHARSET=utf8 ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
	        /*!50100 PARTITION BY HASH (account_id)
	        PARTITIONS 128 */"
	)
  end

  def down
  	drop_table :archive_tickets
  end
end
