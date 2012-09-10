require "helpdesk/ticket"

class TicketObserver < ActiveRecord::Observer

	observe Helpdesk::Ticket

	include Helpdesk::Ticketfields::TicketStatus
	include Gamification::Quests::ProcessTicketQuests

	def after_save(ticket)
		process_available_quests(ticket)
		rollback_achieved_quests(ticket)
	end

	private

	def process_available_quests(ticket)
		if ticket.responder and resolved_now?(ticket)
			evaluate_ticket_quests(ticket)
		end
	end

	def rollback_achieved_quests(ticket)
		if ticket.responder and reopened_now?(ticket)
			ticket.responder.quests.ticket_quests.each do |quest|
				badge_awarded_time = ticket.responder.badge_awarded_at(quest)

				unless quest.any_time_span?
					resolved_in_quest_span = ticket.ticket_states.resolved_at.between?(
						quest.start_time(badge_awarded_time), badge_awarded_time)
				else
					resolved_in_quest_span = ticket.ticket_states.resolved_at <= badge_awarded_time
				end

				if resolved_in_quest_span
					if (evaluate_query(quest,ticket,badge_awarded_time) || evaluate_query(quest,ticket))
						ach_quest = ticket.responder.achieved_quest(quest)
						ach_quest.updated_at = Time.zone.now
						ach_quest.save
					else # Rollback points and badge
						RAILS_DEFAULT_LOGGER.debug %(ROLLBACK POINTS N BADGE of user_id : #{ticket.responder.id} 
									: quest_id : #{quest.id})
						quest.revoke!(ticket.responder)
					end
				end
			end
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
