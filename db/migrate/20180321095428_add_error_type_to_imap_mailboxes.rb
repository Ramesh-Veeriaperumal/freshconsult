class AddErrorTypeToImapMailboxes < ActiveRecord::Migration
  shard :all
  def up
    Lhm.change_table :imap_mailboxes, atomic_switch: true do |m|
      m.add_column :error_type, "SMALLINT DEFAULT NULL"
    end
  end

  def down
    Lhm.change_table :imap_mailboxes, atomic_switch: true do |m|
      m.remove_column :error_type
    end
  end
end
