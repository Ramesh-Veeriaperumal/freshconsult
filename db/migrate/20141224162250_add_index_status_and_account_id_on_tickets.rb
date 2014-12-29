class AddIndexStatusAndAccountIdOnTickets < ActiveRecord::Migration
  shard :all
  def self.up
    add_index :helpdesk_tickets, [ :status, :account_id], 
      :name => "index_helpdesk_tickets_on_status_and_account_id"
  end

  def self.down
    remove_index :helpdesk_tickets, [ :status, :account_id]
  end
end
