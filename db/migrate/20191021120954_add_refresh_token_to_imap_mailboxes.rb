class AddRefreshTokenToImapMailboxes < ActiveRecord::Migration
  shard :all
  def up
    Lhm.change_table :imap_mailboxes, :atomic_switch => true do |m|
      m.add_column :refresh_token, :text
    end
  end

  def down
    Lhm.change_table :imap_mailboxes do |m|
      m.remove_column :refresh_token
    end
  end
end
