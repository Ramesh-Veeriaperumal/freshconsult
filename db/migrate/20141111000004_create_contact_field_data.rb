class CreateContactFieldData < ActiveRecord::Migration
  shard :all
  def self.up
    execute(%(
      CREATE TABLE `contact_field_data` (
        `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        `account_id` bigint(20) DEFAULT NULL,
        `contact_form_id` bigint(20) DEFAULT NULL,
        `user_id` bigint(20) DEFAULT NULL,
        `health` int(11) DEFAULT NULL,
        `priority` varchar(255) DEFAULT NULL,
        `user_external_id` varchar(255) DEFAULT NULL,
        `cf_str01` varchar(255) DEFAULT NULL,
        `cf_str02` varchar(255) DEFAULT NULL,
        `cf_str03` varchar(255) DEFAULT NULL,
        `cf_str04` varchar(255) DEFAULT NULL,
        `cf_str05` varchar(255) DEFAULT NULL,
        `cf_str06` varchar(255) DEFAULT NULL,
        `cf_str07` varchar(255) DEFAULT NULL,
        `cf_str08` varchar(255) DEFAULT NULL,
        `cf_str09` varchar(255) DEFAULT NULL,
        `cf_str10` varchar(255) DEFAULT NULL,
        `cf_str11` varchar(255) DEFAULT NULL,
        `cf_str12` varchar(255) DEFAULT NULL,
        `cf_str13` varchar(255) DEFAULT NULL,
        `cf_str14` varchar(255) DEFAULT NULL,
        `cf_str15` varchar(255) DEFAULT NULL,
        `cf_str16` varchar(255) DEFAULT NULL,
        `cf_str17` varchar(255) DEFAULT NULL,
        `cf_str18` varchar(255) DEFAULT NULL,
        `cf_str19` varchar(255) DEFAULT NULL,
        `cf_str20` varchar(255) DEFAULT NULL,
        `cf_str21` varchar(255) DEFAULT NULL,
        `cf_str22` varchar(255) DEFAULT NULL,
        `cf_str23` varchar(255) DEFAULT NULL,
        `cf_str24` varchar(255) DEFAULT NULL,
        `cf_str25` varchar(255) DEFAULT NULL,
        `cf_str26` varchar(255) DEFAULT NULL,
        `cf_str27` varchar(255) DEFAULT NULL,
        `cf_str28` varchar(255) DEFAULT NULL,
        `cf_str29` varchar(255) DEFAULT NULL,
        `cf_str30` varchar(255) DEFAULT NULL,
        `cf_str31` varchar(255) DEFAULT NULL,
        `cf_str32` varchar(255) DEFAULT NULL,
        `cf_str33` varchar(255) DEFAULT NULL,
        `cf_str34` varchar(255) DEFAULT NULL,
        `cf_str35` varchar(255) DEFAULT NULL,
        `cf_str36` varchar(255) DEFAULT NULL,
        `cf_str37` varchar(255) DEFAULT NULL,
        `cf_str38` varchar(255) DEFAULT NULL,
        `cf_str39` varchar(255) DEFAULT NULL,
        `cf_str40` varchar(255) DEFAULT NULL,
        `cf_str41` varchar(255) DEFAULT NULL,
        `cf_str42` varchar(255) DEFAULT NULL,
        `cf_str43` varchar(255) DEFAULT NULL,
        `cf_str44` varchar(255) DEFAULT NULL,
        `cf_str45` varchar(255) DEFAULT NULL,
        `cf_str46` varchar(255) DEFAULT NULL,
        `cf_str47` varchar(255) DEFAULT NULL,
        `cf_str48` varchar(255) DEFAULT NULL,
        `cf_str49` varchar(255) DEFAULT NULL,
        `cf_str50` varchar(255) DEFAULT NULL,
        `cf_str51` varchar(255) DEFAULT NULL,
        `cf_str52` varchar(255) DEFAULT NULL,
        `cf_str53` varchar(255) DEFAULT NULL,
        `cf_str54` varchar(255) DEFAULT NULL,
        `cf_str55` varchar(255) DEFAULT NULL,
        `cf_str56` varchar(255) DEFAULT NULL,
        `cf_str57` varchar(255) DEFAULT NULL,
        `cf_str58` varchar(255) DEFAULT NULL,
        `cf_str59` varchar(255) DEFAULT NULL,
        `cf_str60` varchar(255) DEFAULT NULL,
        `cf_str61` varchar(255) DEFAULT NULL,
        `cf_str62` varchar(255) DEFAULT NULL,
        `cf_str63` varchar(255) DEFAULT NULL,
        `cf_str64` varchar(255) DEFAULT NULL,
        `cf_str65` varchar(255) DEFAULT NULL,
        `cf_str66` varchar(255) DEFAULT NULL,
        `cf_str67` varchar(255) DEFAULT NULL,
        `cf_str68` varchar(255) DEFAULT NULL,
        `cf_str69` varchar(255) DEFAULT NULL,
        `cf_str70` varchar(255) DEFAULT NULL,
        `cf_str71` varchar(255) DEFAULT NULL,
        `cf_str72` varchar(255) DEFAULT NULL,
        `cf_str73` varchar(255) DEFAULT NULL,
        `cf_str74` varchar(255) DEFAULT NULL,
        `cf_str75` varchar(255) DEFAULT NULL,
        `cf_str76` varchar(255) DEFAULT NULL,
        `cf_text01` text,
        `cf_text02` text,
        `cf_text03` text,
        `cf_text04` text,
        `cf_text05` text,
        `cf_text06` text,
        `cf_text07` text,
        `cf_text08` text,
        `cf_text09` text,
        `cf_text10` text,
        `cf_int01` bigint(20) DEFAULT NULL,
        `cf_int02` bigint(20) DEFAULT NULL,
        `cf_int03` bigint(20) DEFAULT NULL,
        `cf_int04` bigint(20) DEFAULT NULL,
        `cf_int05` bigint(20) DEFAULT NULL,
        `cf_int06` bigint(20) DEFAULT NULL,
        `cf_int07` bigint(20) DEFAULT NULL,
        `cf_int08` bigint(20) DEFAULT NULL,
        `cf_int09` bigint(20) DEFAULT NULL,
        `cf_int10` bigint(20) DEFAULT NULL,
        `cf_int11` bigint(20) DEFAULT NULL,
        `cf_int12` bigint(20) DEFAULT NULL,
        `cf_int13` bigint(20) DEFAULT NULL,
        `cf_int14` bigint(20) DEFAULT NULL,
        `cf_int15` bigint(20) DEFAULT NULL,
        `cf_int16` bigint(20) DEFAULT NULL,
        `cf_int17` bigint(20) DEFAULT NULL,
        `cf_int18` bigint(20) DEFAULT NULL,
        `cf_int19` bigint(20) DEFAULT NULL,
        `cf_int20` bigint(20) DEFAULT NULL,
        `cf_date01` datetime DEFAULT NULL,
        `cf_date02` datetime DEFAULT NULL,
        `cf_date03` datetime DEFAULT NULL,
        `cf_date04` datetime DEFAULT NULL,
        `cf_date05` datetime DEFAULT NULL,
        `cf_date06` datetime DEFAULT NULL,
        `cf_date07` datetime DEFAULT NULL,
        `cf_date08` datetime DEFAULT NULL,
        `cf_date09` datetime DEFAULT NULL,
        `cf_date10` datetime DEFAULT NULL,
        `cf_boolean01` tinyint(1) DEFAULT NULL,
        `cf_boolean02` tinyint(1) DEFAULT NULL,
        `cf_boolean03` tinyint(1) DEFAULT NULL,
        `cf_boolean04` tinyint(1) DEFAULT NULL,
        `cf_boolean05` tinyint(1) DEFAULT NULL,
        `cf_boolean06` tinyint(1) DEFAULT NULL,
        `cf_boolean07` tinyint(1) DEFAULT NULL,
        `cf_boolean08` tinyint(1) DEFAULT NULL,
        `cf_boolean09` tinyint(1) DEFAULT NULL,
        `cf_boolean10` tinyint(1) DEFAULT NULL,
        `cf_decimal01` decimal(15,4) DEFAULT NULL,
        `cf_decimal02` decimal(15,4) DEFAULT NULL,
        `cf_decimal03` decimal(15,4) DEFAULT NULL,
        `cf_decimal04` decimal(15,4) DEFAULT NULL,
        `cf_decimal05` decimal(15,4) DEFAULT NULL,
        `cf_decimal06` decimal(15,4) DEFAULT NULL,
        `cf_decimal07` decimal(15,4) DEFAULT NULL,
        `cf_decimal08` decimal(15,4) DEFAULT NULL,
        `cf_decimal09` decimal(15,4) DEFAULT NULL,
        `cf_decimal10` decimal(15,4) DEFAULT NULL,
        `long_uc01` bigint(20) DEFAULT NULL,
        `long_uc02` bigint(20) DEFAULT NULL,
        `long_uc03` bigint(20) DEFAULT NULL,
        `long_uc04` bigint(20) DEFAULT NULL,
        `long_uc05` bigint(20) DEFAULT NULL,
        `int_uc01` int(11) DEFAULT NULL,
        `int_uc02` int(11) DEFAULT NULL,
        `int_uc03` int(11) DEFAULT NULL,
        `int_uc04` int(11) DEFAULT NULL,
        `int_uc05` int(11) DEFAULT NULL,
        `string_uc07` varchar(255) DEFAULT NULL,
        `string_uc08` varchar(255) DEFAULT NULL,
        `string_uc09` varchar(255) DEFAULT NULL,
        `string_uc10` varchar(255) DEFAULT NULL,
        `string_uc11` varchar(255) DEFAULT NULL,
        `string_uc12` varchar(255) DEFAULT NULL,
        `datetime_uc01` datetime DEFAULT NULL,
        `datetime_uc02` datetime DEFAULT NULL,
        `boolean_uc01` tinyint(1) DEFAULT '0',
        `boolean_uc02` tinyint(1) DEFAULT '0',
        `boolean_uc03` tinyint(1) DEFAULT '0',
        `boolean_uc04` tinyint(1) DEFAULT '0',
        `boolean_uc05` tinyint(1) DEFAULT '0',
        `text_uc02` text,
        `created_at` datetime DEFAULT NULL,
        `updated_at` datetime DEFAULT NULL,
        PRIMARY KEY (`account_id`,`id`),
        KEY `index_contact_field_data_on_account_id_and_user_id` (`account_id`,`user_id`),
        KEY `index_contact_field_data_on_account_id_and_contact_form_id` (`account_id`,`contact_form_id`),
        KEY `index_contact_field_data_on_account_id_and_long_uc01` (`account_id`,`long_uc01`),
        KEY `index_contact_field_data_on_account_id_and_int_uc01` (`account_id`,`int_uc01`),
        KEY `index_contact_field_data_on_account_id_and_user_external_id` (`account_id`,`user_external_id`(30)),
        KEY `index_contact_field_data_on_account_id_and_priority` (`account_id`,`priority`(20)),
        KEY `index_contact_field_data_id` (`id`)
      ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8
      /*!50100 PARTITION BY HASH (account_id)
      PARTITIONS 128 */;
    ))
  end
end
