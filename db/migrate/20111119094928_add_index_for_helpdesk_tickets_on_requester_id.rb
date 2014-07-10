class AddIndexForHelpdeskTicketsOnRequesterId < ActiveRecord::Migration
  def self.up
    add_index :helpdesk_tickets, :requester_id, :name => 'index_helpdesk_tickets_on_requester_id'
    add_index :helpdesk_activities, [:notable_type, :notable_id], :name => 'helpdesk_activities_notable_type_and_id'
  end

  def self.down
     remove_index(:helpdesk_tickets, :name => 'index_helpdesk_tickets_on_requester_id')
     remove_index(:helpdesk_activities, :name => 'helpdesk_activities_notable_type_and_id')
  end
end
