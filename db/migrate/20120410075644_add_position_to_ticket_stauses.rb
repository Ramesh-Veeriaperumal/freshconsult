class AddPositionToTicketStauses < ActiveRecord::Migration
  def self.up
  	add_column :helpdesk_ticket_statuses, :position, :integer
  end

  def self.down
  	remove_column :helpdesk_ticket_statuses, :position
  end
end
