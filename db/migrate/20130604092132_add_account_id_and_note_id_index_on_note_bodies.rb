class AddAccountIdAndNoteIdIndexOnNoteBodies < ActiveRecord::Migration
  shard :none
  def self.up
  	remove_index :helpdesk_note_bodies, [:account_id, :note_id]
  	add_index :helpdesk_note_bodies, [:account_id, :note_id], :name => 'index_note_bodies_on_account_id_and_note_id', :unique => true
  end

  def self.down
  	remove_index :helpdesk_note_bodies, [:account_id, :note_id]
  end
end
