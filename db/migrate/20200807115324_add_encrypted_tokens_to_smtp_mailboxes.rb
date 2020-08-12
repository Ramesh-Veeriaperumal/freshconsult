# frozen_string_literal: true

class AddEncryptedTokensToSmtpMailboxes < ActiveRecord::Migration
  def up
    Lhm.change_table :smtp_mailboxes, atomic_switch: true do |m|
      m.add_column :encrypted_access_token, :text
      m.rename_column :refresh_token, :encrypted_refresh_token
    end
  end

  def down
    Lhm.change_table :smtp_mailboxes do |m|
      m.remove_column :encrypted_access_token
      m.rename_column :encrypted_refresh_token, :refresh_token
    end
  end
end
