class AddActivatorColumnsToEmailConfigs < ActiveRecord::Migration
  def self.up
    add_column :email_configs, :active, :boolean, :default => false
    add_column :email_configs, :activator_token, :string
    
    execute "update email_configs set active=1"
  end

  def self.down
    remove_column :email_configs, :activator_token
    remove_column :email_configs, :active
  end
end
