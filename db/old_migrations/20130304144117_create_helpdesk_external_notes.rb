class CreateHelpdeskExternalNotes < ActiveRecord::Migration
  shard :none
  def self.up
    execute("CREATE TABLE `helpdesk_external_notes` (
            `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
            `account_id` bigint(20) unsigned DEFAULT NULL,
            `note_id` bigint(20) unsigned DEFAULT NULL,
            `installed_application_id` bigint(20) unsigned DEFAULT NULL,
            `external_id` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
            index `helpdesk_external_notes_id`(`id`),
            index `index_helpdesk_external_id` (`account_id`,`installed_application_id`,`external_id`(20))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci PARTITION BY  HASH(account_id) PARTITIONS 128")
  end

  def self.down
    drop_table :helpdesk_external_notes
  end
end
