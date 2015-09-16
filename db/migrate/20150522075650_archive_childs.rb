class ArchiveChilds < ActiveRecord::Migration
  shard :none
  def up
  	execute("CREATE TABLE `archive_childs` (
		    `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
	        `account_id` bigint(20) unsigned NOT NULL,
	        `archive_ticket_id` bigint(20) unsigned DEFAULT NULL,
	        `ticket_id` bigint(20) unsigned DEFAULT NULL,
	        KEY `index_on_account_id_and_archive_ticket_id` (`account_id`,`archive_ticket_id`),
	        KEY `index_on_account_id_and_ticket_id` (`account_id`,`ticket_id`),
	        KEY `index_on_id` (`id`),
	        PRIMARY KEY (`account_id`,`id`)
	        )ENGINE=InnoDB DEFAULT CHARSET=utf8 ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
	        /*!50100 PARTITION BY HASH (account_id)
	        PARTITIONS 128 */"
	    )
  end

  def down
  	drop_table :archive_childs
  end
end
