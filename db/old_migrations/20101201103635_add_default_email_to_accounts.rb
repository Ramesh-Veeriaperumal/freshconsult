class AddDefaultEmailToAccounts < ActiveRecord::Migration
  def self.up
    add_column :accounts, :default_email, :string
  end

  def self.down
    remove_column :accounts, :default_email
  end
end
