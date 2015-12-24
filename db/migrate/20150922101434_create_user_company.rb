class CreateUserCompany < ActiveRecord::Migration

  shard :all

  def self.up
    execute("CREATE TABLE `user_companies` (`id` BIGINT UNSIGNED DEFAULT NULL auto_increment, `user_id` bigint, `company_id` bigint, `account_id` bigint, `default` tinyint(1), `created_at` datetime NOT NULL, `updated_at` datetime NOT NULL, PRIMARY KEY (id, account_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci PARTITION BY  HASH(account_id) PARTITIONS 128")
    
    add_index :user_companies, [:account_id, :user_id, :company_id], 
              :name => "index_user_companies_on_account_id_user_id_company_id"
    add_index :user_companies, [:account_id, :user_id], 
              :name => "index_user_companies_on_account_id_user_id"
    add_index :user_companies, [:account_id, :company_id], 
              :name => "index_user_companies_on_account_id_company_id"
  end

  def self.down
    drop_table :user_companies
  end
end
