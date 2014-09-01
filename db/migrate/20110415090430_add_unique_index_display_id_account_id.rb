class AddUniqueIndexDisplayIdAccountId < ActiveRecord::Migration
  def self.up
	add_index :helpdesk_tickets, [:account_id, :display_id], :name => 'index_helpdesk_tickets_on_account_id_and_display_id', :unique => true
  end

  def self.down
	remove_index :helpdesk_tickets, [:account_id, :display_id]
  end
end
