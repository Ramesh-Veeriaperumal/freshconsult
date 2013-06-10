class AddIndexIdOnHelpdeskNoteBodies < ActiveRecord::Migration
  def self.up
  	add_index :helpdesk_note_bodies, :id, :name => 'index_helpdesk_note_bodies_id'
  end

  def self.down
  	remove_index :helpdesk_note_bodies, :id
  end
end
