class CreateEmailCommandsSettings < ActiveRecord::Migration
  def self.up
    create_table :email_commands_settings do |t|
      t.string :email_cmds_delimeter
      t.column :account_id, "bigint unsigned"
      t.timestamps
    end
    Account.all.each do |account|
      account.create_email_commands_setting(:email_cmds_delimeter => "@Simonsays")
    end
  end

  def self.down
    drop_table :email_commands_settings
  end
end
