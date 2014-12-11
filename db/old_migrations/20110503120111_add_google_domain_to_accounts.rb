class AddGoogleDomainToAccounts < ActiveRecord::Migration
  def self.up
    add_column :accounts, :google_domain, :string
  end

  def self.down
    remove_column :accounts, :google_domain
  end
end
