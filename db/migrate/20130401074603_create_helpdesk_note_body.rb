class CreateHelpdeskNoteBody < ActiveRecord::Migration
  shard :none
  def self.up
  	execute("CREATE TABLE `helpdesk_note_bodies` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `note_id` bigint(20) DEFAULT NULL,
  `body` mediumtext COLLATE utf8_unicode_ci,
  `body_html` mediumtext COLLATE utf8_unicode_ci,
  `full_text` mediumtext COLLATE utf8_unicode_ci,
  `full_text_html` mediumtext COLLATE utf8_unicode_ci,
  `account_id` bigint(20) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  KEY `index_helpdesk_note_bodies_id` (`id`),
  KEY `index_helpdesk_note_bodies_on_account_id_and_note_id` (`account_id`,`note_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
PARTITION BY HASH(account_id)
PARTITIONS 128;")
  end

  def self.down
  end
end
