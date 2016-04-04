class AddAccountIdOnGoogleContacts < ActiveRecord::Migration
  def self.up
  	add_column :google_contacts, :account_id, "bigint unsigned"
  end

  def self.down
  	remove_column :google_contacts, :account_id
  end
end
