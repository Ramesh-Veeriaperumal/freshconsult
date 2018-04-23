class CreateCompanyNoteBodies < ActiveRecord::Migration
  shard :none

  def up
    execute("CREATE TABLE `company_note_bodies` (
      `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
      `body` mediumtext COLLATE utf8_unicode_ci,
      `company_note_id` bigint(20) unsigned DEFAULT NULL,
      `account_id` bigint(20) unsigned NOT NULL,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      KEY `index_company_note_bodies_on_id_and_account_id` (`id`, `account_id`),
      KEY `index_company_note_bodies_on_account_id_and_company_note_id` (`account_id`, `company_note_id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
      PARTITION BY HASH(account_id)
      PARTITIONS 128;")
  end

  def down
    drop_table :company_note_bodies
  end
end
