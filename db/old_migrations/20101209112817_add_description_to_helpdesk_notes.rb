class AddDescriptionToHelpdeskNotes < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_notes, :description, :text
  end

  def self.down
    remove_column :helpdesk_notes, :description
  end
end
