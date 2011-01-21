class RemoveSolutionFolderIdFromHelpdeskGuides < ActiveRecord::Migration
  def self.up
    remove_column :helpdesk_guides, :solution_folder_id
    add_column :helpdesk_guides, :folder_id, :integer
  end

  def self.down
    add_column :helpdesk_guides, :solution_folder_id, :integer
    remove_column :helpdesk_guides, :folder_id
  end
end
