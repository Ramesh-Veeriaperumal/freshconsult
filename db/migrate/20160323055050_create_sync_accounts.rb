class CreateSyncAccounts < ActiveRecord::Migration

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :sync_accounts do |t|
      t.string :name
      t.string :email
      t.string :oauth_token, :limit => 1000
      t.string :refresh_token, :limit => 1000
      t.column :account_id, "bigint unsigned"
      t.column :installed_application_id, "bigint unsigned"
      t.boolean :active, :default => true
      t.string :sync_group_id
      t.string :sync_group_name, :null => false, :default => 'Freshdesk Contacts'
      t.column :sync_tag_id, "bigint unsigned"
      t.datetime :sync_start_time
      t.datetime :last_sync_time
      t.boolean :overwrite_existing_user, :default => false
      t.string :last_sync_status
      t.text :configs
      t.timestamps
    end
    add_index :sync_accounts, [:installed_application_id, :account_id, :email], :unique => true, :name => "index_sync_accounts_on_inst_ap_id_acc_id_email"
  end

  def down
    drop_table :sync_accounts
  end

end
