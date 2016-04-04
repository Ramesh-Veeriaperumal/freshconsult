class ArchiveNotes < ActiveRecord::Migration
  shard :none
  def up
  	execute("CREATE TABLE `archive_notes` (
		    `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
	        `user_id` bigint(20) unsigned DEFAULT NULL,
	        `account_id` bigint(20) unsigned NOT NULL,
	        `note_id` bigint(20) unsigned DEFAULT NULL,
	        `notable_id` bigint(20) unsigned DEFAULT NULL,
	        `archive_ticket_id` bigint(20) unsigned DEFAULT NULL,
	        `source` int(11) DEFAULT '0',
  			`incoming` tinyint(1) DEFAULT '0',
  			`private` tinyint(1) DEFAULT '1',
	        `created_at` datetime DEFAULT NULL,
	        `updated_at` datetime DEFAULT NULL,
	        KEY `index_archive_notes_on_account_id_and_archive_ticket_id` (`account_id`,`archive_ticket_id`),
	        KEY `index_archive_notes_on_account_id_and_user_id` (`account_id`,`user_id`),
	        KEY `index_archive_notes_on_account_id_and_note_id` (`account_id`,`note_id`),
	        KEY `index_on_id` (`id`),
	        PRIMARY KEY (`account_id`,`id`)
	        )ENGINE=InnoDB DEFAULT CHARSET=utf8 ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
	        /*!50100 PARTITION BY HASH (account_id)
	        PARTITIONS 128 */"
	    )
  end

  def down
  	drop_table :archive_notes
  end
end
