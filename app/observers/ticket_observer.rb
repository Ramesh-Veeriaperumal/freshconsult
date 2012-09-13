require "helpdesk/ticket"

class TicketObserver < ActiveRecord::Observer

	observe Helpdesk::Ticket

	include Helpdesk::Ticketfields::TicketStatus
	include Gamification::GamificationUtil

	def after_save(ticket)
		if gamification_feature?(ticket.account)
			process_available_quests(ticket)
			rollback_achieved_quests(ticket)
		end
	end

	private

	def process_available_quests(ticket)
		if ticket.responder and resolved_now?(ticket)
			Resque.enqueue(Gamification::Quests::ProcessTicketQuests, { :id => ticket.id, 
							:account_id => ticket.account_id })
		end
	end

	def rollback_achieved_quests(ticket)
		if ticket.responder and reopened_now?(ticket)
			Resque.enqueue(Gamification::Quests::ProcessTicketQuests, { :id => ticket.id, 
							:account_id => ticket.account_id, :rollback => true,
							:resolved_time_was => ticket.ticket_states.resolved_time_was })
		end
	end

	def resolved_now?(ticket)
		ticket.status_changed? && ((ticket.resolved? && ticket.status_was != CLOSED) ||
			(ticket.closed? && ticket.status_was != RESOLVED))
	end

	def reopened_now?(ticket)
		ticket.status_changed? && (ticket.active? && 
			[RESOLVED, CLOSED].include?(ticket.status_was))
	end

end
