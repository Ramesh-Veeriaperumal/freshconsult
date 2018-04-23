class CreateCompanyNotes < ActiveRecord::Migration
  shard :none

  def up
    execute("CREATE TABLE `company_notes` (
      `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
      `title` varchar(255) COLLATE utf8_unicode_ci,
      `category_id` tinyint(3) unsigned DEFAULT NULL,
      `account_id` bigint(20) unsigned NOT NULL,
      `created_by` bigint(20) NOT NULL,
      `last_updated_by` bigint(20) DEFAULT NULL,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      `s3_key` tinyint(1) DEFAULT '0',
      `company_id` bigint(20) unsigned NOT NULL,
      KEY `index_company_notes_on_id_and_account_id` (`id`, `account_id`),
      KEY `index_company_notes_on_account_id_and_company_id_and_created_at` (`account_id`, `company_id`, `created_at`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
      PARTITION BY HASH(account_id)
      PARTITIONS 128;")
  end

  def down
    drop_table :company_notes
  end
end
