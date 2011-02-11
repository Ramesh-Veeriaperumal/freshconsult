class RemoveDescriptionFromHelpdeskNotes < ActiveRecord::Migration
  def self.up
    remove_column :helpdesk_notes, :description
  end

  def self.down
    add_column :helpdesk_notes, :description, :text
  end
end
