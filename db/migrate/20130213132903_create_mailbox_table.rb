class CreateMailboxTable < ActiveRecord::Migration

  shard :all
  def self.up
    create_table :mailboxes do |t|
      t.column   :email_config_id, "bigint unsigned"
      t.column   :account_id, "bigint unsigned"
      t.string   :imap_server_name
      t.string   :imap_user_name
      t.text     :imap_password
      t.integer  :imap_port
      t.string   :imap_authentication
      t.boolean  :imap_use_ssl
      t.string   :imap_folder
      t.boolean  :imap_delete_from_server
      t.string   :smtp_server_name
      t.string   :smtp_user_name
      t.text     :smtp_password
      t.integer  :smtp_port
      t.string   :smtp_authentication
      t.boolean  :smtp_use_ssl
      t.boolean  :imap_enabled, :default => true
      t.boolean  :smtp_enabled, :default => true
      t.integer  :imap_timeout

      t.timestamps
    end

    add_index "mailboxes", ["account_id", "email_config_id"], :name => "index_mailboxes_on_account_id_email_config_id"

  end

  def self.down
  	drop_table :mailboxes
  end
end
