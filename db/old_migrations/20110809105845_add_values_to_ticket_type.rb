class AddValuesToTicketType < ActiveRecord::Migration
  def self.up
    execute "update helpdesk_tickets set tkt_type = 'Question' where ticket_type = 1 "
    execute "update helpdesk_tickets set tkt_type = 'Incident' where ticket_type = 2 "
    execute "update helpdesk_tickets set tkt_type = 'Problem' where ticket_type = 3 "
    execute "update helpdesk_tickets set tkt_type = 'Feature Request' where ticket_type = 4 "
    execute "update helpdesk_tickets set tkt_type = 'Lead' where ticket_type = 5 "
  end

  def self.down
  end
end
