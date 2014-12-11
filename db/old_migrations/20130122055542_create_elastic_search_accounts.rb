class CreateElasticSearchAccounts < ActiveRecord::Migration
  def self.up
    create_table :es_enabled_accounts do |t|
      t.integer "account_id", :limit => 8
      t.string "index_name"
    end

    add_index "es_enabled_accounts", ["account_id"], :name => "index_es_enabled_accounts_on_account_id"
  end

  def self.down
    drop_table :es_enabled_accounts
  end
end
