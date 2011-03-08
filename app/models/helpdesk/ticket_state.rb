class Helpdesk::TicketState < ActiveRecord::Base
  set_table_name "helpdesk_ticket_states"
  belongs_to :tickets , :class_name =>'Helpdesk::Ticket'
end
