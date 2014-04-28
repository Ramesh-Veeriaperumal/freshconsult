class CreateSmtpMailboxes < ActiveRecord::Migration

  shard :all
  def self.up
    create_table :smtp_mailboxes do |t|
      t.column   :email_config_id, "bigint unsigned"
      t.column   :account_id, "bigint unsigned"
      t.string   :server_name
      t.string   :user_name
      t.text     :password
      t.integer  :port
      t.string   :authentication
      t.boolean  :use_ssl
      t.boolean  :enabled, :default => true
      t.string   :domain

      t.timestamps
    end

    add_index "smtp_mailboxes", ["account_id", "email_config_id"], :name => "index_mailboxes_on_account_id_email_config_id"
  end

  def self.down
    drop_table :smtp_mailboxes
  end
end