class AddAppTypeToApplications < ActiveRecord::Migration
  shard :none
  def self.up
    # add_column :applications, :application_type, :string, :null => false, :default => "freshplug"
    execute("ALTER TABLE `applications` ADD `application_type` varchar(255) DEFAULT 'freshplug' NOT NULL")
    # Integrations::Application.find_all_by_account_id(0).each{ |application|
    #     application.update_attributes(:application_type => application.name)
    # }
    execute("UPDATE `applications` SET `application_type` = `applications`.name where account_id = 0 ")
  end

  def self.down
    execute("ALTER TABLE `applications` DROP `application_type`")
  end
end
