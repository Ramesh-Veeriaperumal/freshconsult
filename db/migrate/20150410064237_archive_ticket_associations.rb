class ArchiveTicketAssociations < ActiveRecord::Migration
  shard :none
  def up
  	execute("
  			CREATE TABLE `archive_ticket_associations` (
		    `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
	        `account_id` bigint(20) unsigned NOT NULL,
	        `archive_ticket_id` bigint(20) DEFAULT NULL,
	        `description` longtext,
	        `description_html` longtext,
	        `association_data` longtext,
	        KEY `index_on_account_id_and_archive_ticket_id` (`account_id`,`archive_ticket_id`),
	        KEY `index_on_id` (`id`),
	        PRIMARY KEY (`account_id`,`id`)

	        )ENGINE=InnoDB DEFAULT CHARSET=utf8 ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
	        /*!50100 PARTITION BY HASH (account_id)
	        PARTITIONS 128 */"
	    )
  end

  def down
  	drop_table :archive_ticket_associations
  end
end
