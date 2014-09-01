class CreateImapMailboxes < ActiveRecord::Migration

  shard :all
  def self.up
    create_table :imap_mailboxes do |t|
      t.column   :email_config_id, "bigint unsigned"
      t.column   :account_id, "bigint unsigned"
      t.string   :server_name
      t.string   :user_name
      t.text     :password
      t.integer  :port
      t.string   :authentication
      t.boolean  :use_ssl
      t.string   :folder
      t.boolean  :delete_from_server
      t.boolean  :enabled, :default => true
      t.integer  :timeout

      t.timestamps
    end

    add_index "imap_mailboxes", ["account_id", "email_config_id"], :name => "index_mailboxes_on_account_id_email_config_id"
  end

  def self.down
    drop_table :imap_mailboxes
  end
end