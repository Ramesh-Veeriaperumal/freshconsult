class CreateHelpdeskSchemaLessNotes < ActiveRecord::Migration
  def self.up

  	execute("CREATE TABLE `helpdesk_schema_less_notes` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `note_id` bigint(20) unsigned DEFAULT NULL,
  `account_id` bigint(20) unsigned DEFAULT NULL,
  `from_email` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `to_emails` text COLLATE utf8_unicode_ci,
  `cc_emails` text COLLATE utf8_unicode_ci,
  `bcc_emails` text COLLATE utf8_unicode_ci,
  `long_nc01` bigint(20) unsigned DEFAULT NULL,
  `long_nc02` bigint(20) unsigned DEFAULT NULL,
  `long_nc03` bigint(20) unsigned DEFAULT NULL,
  `long_nc04` bigint(20) unsigned DEFAULT NULL,
  `long_nc05` bigint(20) unsigned DEFAULT NULL,
  `long_nc06` bigint(20) unsigned DEFAULT NULL,
  `long_nc07` bigint(20) unsigned DEFAULT NULL,
  `long_nc08` bigint(20) unsigned DEFAULT NULL,
  `long_nc09` bigint(20) unsigned DEFAULT NULL,
  `long_nc10` bigint(20) unsigned DEFAULT NULL,
  `int_nc01` int(11) DEFAULT NULL,
  `int_nc02` int(11) DEFAULT NULL,
  `int_nc03` int(11) DEFAULT NULL,
  `int_nc04` int(11) DEFAULT NULL,
  `int_nc05` int(11) DEFAULT NULL,
  `string_nc01` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `string_nc02` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `string_nc03` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `string_nc04` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `string_nc05` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `string_nc06` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `string_nc07` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `string_nc08` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `string_nc09` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `string_nc10` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `string_nc11` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `string_nc12` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `string_nc13` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `string_nc14` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `string_nc15` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `datetime_nc01` datetime DEFAULT NULL,
  `datetime_nc02` datetime DEFAULT NULL,
  `datetime_nc03` datetime DEFAULT NULL,
  `datetime_nc04` datetime DEFAULT NULL,
  `datetime_nc05` datetime DEFAULT NULL,
  `boolean_nc01` tinyint(1) DEFAULT '0',
  `boolean_nc02` tinyint(1) DEFAULT '0',
  `boolean_nc03` tinyint(1) DEFAULT '0',
  `boolean_nc04` tinyint(1) DEFAULT '0',
  `boolean_nc05` tinyint(1) DEFAULT '0',
  `text_nc01` text COLLATE utf8_unicode_ci,
  `text_nc02` text COLLATE utf8_unicode_ci,
  `text_nc03` text COLLATE utf8_unicode_ci,
  `text_nc04` text COLLATE utf8_unicode_ci,
  `text_nc05` text COLLATE utf8_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  UNIQUE KEY `index_helpdesk_schema_less_notes_on_account_id_note_id` (`account_id`,`note_id`),
  KEY `helpdesk_schema_less_notes_id` (`id`),
  KEY `index_helpdesk_schema_less_notes_on_long_nc01_account_id` (`long_nc01`,`account_id`),
  KEY `index_helpdesk_schema_less_notes_on_long_nc02_account_id` (`long_nc02`,`account_id`),
  KEY `index_helpdesk_schema_less_notes_on_int_nc01_account_id` (`int_nc01`,`account_id`),
  KEY `index_helpdesk_schema_less_notes_on_int_nc02_account_id` (`int_nc02`,`account_id`),
  KEY `index_helpdesk_schema_less_notes_on_account_id_string_nc01` (`account_id`,`string_nc01`(10)),
  KEY `index_helpdesk_schema_less_notes_on_account_id_string_nc02` (`account_id`,`string_nc02`(10))
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
PARTITION BY HASH(account_id)
PARTITIONS 128;")

  end

  def self.down
  	drop_table :helpdesk_schema_less_notes
  end
end
