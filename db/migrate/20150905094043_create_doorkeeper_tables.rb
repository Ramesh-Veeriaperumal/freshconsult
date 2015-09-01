class CreateDoorkeeperTables < ActiveRecord::Migration
  shard :all

  def change
    create_table :oauth_applications do |t|
      t.string  :name,         null: false
      t.string  :uid,          null: false
      t.string  :secret,       null: false
      t.text    :redirect_uri, null: false
      t.string  :scopes,       null: false, default: ''
      t.column  :user_id,       "bigint unsigned"
      t.column  :account_id,    "bigint unsigned"
      t.timestamps
    end

    add_index :oauth_applications, :uid, :unique => true

    create_table :oauth_access_grants do |t|
      t.column   :account_id,    "bigint unsigned"
      t.integer  :resource_owner_id, null: false
      t.integer  :application_id,    null: false
      t.string   :token,             null: false
      t.integer  :expires_in,        null: false
      t.text     :redirect_uri,      null: false
      t.datetime :created_at,        null: false
      t.datetime :revoked_at
      t.string   :scopes
    end

    add_index :oauth_access_grants, [:account_id, :token], :unique => true

    create_table :oauth_access_tokens do |t|
      t.column   :account_id,    "bigint unsigned"
      t.integer  :resource_owner_id
      t.integer  :application_id
      t.string   :token,             null: false
      t.string   :refresh_token
      t.integer  :expires_in
      t.datetime :revoked_at
      t.datetime :created_at,        null: false
      t.string   :scopes
    end
    
    add_index :oauth_access_tokens, [:account_id, :application_id, :resource_owner_id], :name => 'index_on_acc_id_usr_id_app_id'
    add_index :oauth_access_tokens, [:account_id, :refresh_token], :unique => true
    add_index :oauth_access_tokens, [:account_id, :token], :unique => true
  end
end
