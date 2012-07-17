class RenameEmailCommandsSettingsTable < ActiveRecord::Migration
  def self.up
  	rename_table :email_commands_settings, :account_additional_settings

  	execute("alter table account_additional_settings add column bcc_email varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL")

  	execute("update account_additional_settings a inner join email_configs e on a.account_id = e.account_id set a.bcc_email = e.bcc_email")

  	execute("alter table email_configs drop column bcc_email")
  end

  def self.down
  	execute("alter table email_configs add column bcc_email varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL")

  	execute("update email_configs e inner join account_additional_settings a on a.account_id = e.account_id set e.bcc_email = a.bcc_email")

  	execute("alter table account_additional_settings drop column bcc_email")

  	rename_table :account_additional_settings, :email_commands_settings  	
  end
end
