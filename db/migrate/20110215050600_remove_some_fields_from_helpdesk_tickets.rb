class RemoveSomeFieldsFromHelpdeskTickets < ActiveRecord::Migration
  def self.up
    remove_column :helpdesk_tickets, :id_token
    remove_column :helpdesk_tickets, :organization_id
    remove_column :helpdesk_tickets, :first_assigned_at
    remove_column :helpdesk_tickets, :assigned_at
    remove_column :helpdesk_tickets, :completed_at
    remove_column :helpdesk_tickets, :response_time
  end

  def self.down
    add_column :helpdesk_tickets, :response_time, :datetime
    add_column :helpdesk_tickets, :completed_at, :datetime
    add_column :helpdesk_tickets, :assigned_at, :datetime
    add_column :helpdesk_tickets, :first_assigned_at, :datetime
    add_column :helpdesk_tickets, :organization_id, :integer
    add_column :helpdesk_tickets, :id_token, :string
  end
end
