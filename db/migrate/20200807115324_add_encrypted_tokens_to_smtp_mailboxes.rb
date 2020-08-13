# frozen_string_literal: true

class AddEncryptedTokensToSmtpMailboxes < ActiveRecord::Migration
  shard :all
  def up
    Lhm.change_table :smtp_mailboxes, atomic_switch: true do |m|
      m.add_column :encrypted_access_token, :text
    end
    rename_column :smtp_mailboxes, :refresh_token, :encrypted_refresh_token
  end

  def down
    Lhm.change_table :smtp_mailboxes do |m|
      m.remove_column :encrypted_access_token
    end
    rename_column :smtp_mailboxes, :encrypted_refresh_token, :refresh_token
  end
end
