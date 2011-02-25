class AddIndexToNote < ActiveRecord::Migration
  def self.up
    add_index :helpdesk_notes, :notable_id
    add_index :helpdesk_notes, :notable_type
  end

  def self.down
    remove_index :helpdesk_notes, :notable_id
    remove_index :helpdesk_notes, :notable_type
  end
end
