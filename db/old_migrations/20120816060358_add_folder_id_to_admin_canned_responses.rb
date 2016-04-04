class AddFolderIdToAdminCannedResponses < ActiveRecord::Migration
  def self.up
    add_column :admin_canned_responses, :folder_id, "bigint unsigned"
  end

  def self.down
    remove_column :admin_canned_responses, :folder_id
  end
end
