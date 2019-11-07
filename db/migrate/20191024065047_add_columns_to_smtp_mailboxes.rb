class AddColumnsToSmtpMailboxes < ActiveRecord::Migration
  shard :all
  def up
    Lhm.change_table :smtp_mailboxes, :atomic_switch => true do |m|
      m.add_column :refresh_token, :text
      m.add_column :error_type, "SMALLINT DEFAULT NULL"
    end
  end

  def down
    Lhm.change_table :smtp_mailboxes do |m|
      m.remove_column :refresh_token
      m.remove_column :error_type
    end
  end
end
