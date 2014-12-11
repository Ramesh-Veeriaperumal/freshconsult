class AddSslEnabledToAccounts < ActiveRecord::Migration
  def self.up
    add_column :accounts, :ssl_enabled, :boolean, :default => false
  end

  def self.down
    remove_column :accounts, :ssl_enabled
  end
end
