class AddMoreToHelpdeskTicket < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tickets, :subject, :string
    add_column :helpdesk_tickets, :display_id, :integer
    add_column :helpdesk_tickets, :ticket_type_id, :integer
    add_column :helpdesk_tickets, :priority_id, :integer
    add_column :helpdesk_tickets, :organization_id, :integer
    add_column :helpdesk_tickets, :owner_id, :integer
    add_column :helpdesk_tickets, :group_id, :integer
    add_column :helpdesk_tickets, :first_assigned_at, :datetime
    add_column :helpdesk_tickets, :assigned_at, :datetime
    add_column :helpdesk_tickets, :due_by, :datetime
    add_column :helpdesk_tickets, :completed_at, :datetime
  end

  def self.down
    remove_column :helpdesk_tickets, :completed_at
    remove_column :helpdesk_tickets, :due_by
    remove_column :helpdesk_tickets, :assigned_at
    remove_column :helpdesk_tickets, :first_assigned_at
    remove_column :helpdesk_tickets, :group_id
    remove_column :helpdesk_tickets, :owner_id
    remove_column :helpdesk_tickets, :organization_id
    remove_column :helpdesk_tickets, :priority_id
    remove_column :helpdesk_tickets, :ticket_type_id
    remove_column :helpdesk_tickets, :display_id
    remove_column :helpdesk_tickets, :subject
  end
end
