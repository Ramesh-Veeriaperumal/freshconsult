class AddPassThroughEnabledToEmailCommandsSettings < ActiveRecord::Migration
  def self.up
    add_column :email_commands_settings, :pass_through_enabled, :boolean, :default => true
  end

  def self.down
    remove_column :email_commands_settings, :pass_through_enabled
  end
end
