require "helpdesk/ticket"

class TicketObserver < ActiveRecord::Observer

	observe Helpdesk::Ticket

	include ProcessQuests
	
	def after_create(ticket)
		process_tickets_quest(ticket) if ticket.resolved?
	end

	def after_update(ticket)
		process_tickets_quest(ticket) if ticket.resolved?
	end
	
end
