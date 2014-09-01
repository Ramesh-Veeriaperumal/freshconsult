class AddSsoOptionsToAccount < ActiveRecord::Migration
  def self.up
    add_column :accounts, :sso_enabled, :boolean, :default => false
    add_column :accounts, :shared_secret, :string
    add_column :accounts, :sso_options, :text
  end

  def self.down
    remove_column :accounts, :sso_options
    remove_column :accounts, :shared_secret
    remove_column :accounts, :sso_enabled
  end
end
