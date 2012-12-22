class AddIndexAccountIdFolderIdTitleToCaResponses < ActiveRecord::Migration
  def self.up
  	remove_index :admin_canned_responses, [:account_id, :created_at]
  	add_index :admin_canned_responses, [:account_id, :folder_id, :title], :length => { :title => 20 }, :name => "Index_ca_responses_on_account_id_folder_id_and_title"
  	add_index :ca_folders, :account_id, :name => "Index_ca_folders_on_account_id"
  end

  def self.down
  	remove_index :admin_canned_responses, [:account_id, :folder_id, :title]
  	remove_index :ca_folders, :account_id
  end
end
