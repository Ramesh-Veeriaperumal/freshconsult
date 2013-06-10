class Helpdesk::TicketBody < ActiveRecord::Base

	set_table_name "helpdesk_ticket_bodies"
	belongs_to_account
	belongs_to :ticket, :class_name => 'Helpdesk::Ticket', :foreign_key => 'ticket_id'
	unhtml_it :description
	xss_sanitize :only => [:description_html],  :html_sanitize => [:description_html]
	attr_protected :account_id

	
end