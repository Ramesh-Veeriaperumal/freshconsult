class AddSolutionFolderIdToHelpdeskGuides < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_guides, :solution_folder_id, :integer
  end

  def self.down
    remove_column :helpdesk_guides, :solution_folder_id
  end
end
