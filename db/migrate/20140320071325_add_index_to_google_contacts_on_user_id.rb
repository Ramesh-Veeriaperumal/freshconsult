class AddIndexToGoogleContactsOnUserId < ActiveRecord::Migration
  shard :all	
  def self.up
  	add_index :google_contacts, [:account_id, :user_id], :name => 'index_google_contacts_on_account_id_user_id' 
  end

  def self.down
  	remove_index(:google_contacts, :name => 'index_google_contacts_on_account_id_user_id')
  end
end
