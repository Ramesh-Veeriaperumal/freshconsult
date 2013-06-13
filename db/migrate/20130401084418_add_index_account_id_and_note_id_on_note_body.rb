class AddIndexAccountIdAndNoteIdOnNoteBody < ActiveRecord::Migration
   def self.up
  	add_index :helpdesk_note_bodies, [:account_id, :note_id], :name => 'index_helpdesk_note_bodies_on_account_id_and_note_id'
  end

  def self.down
  	remove_index :helpdesk_note_bodies, [:account_id, :note_id]
  end
end
