require "helpdesk/ticket"

class TicketObserver < ActiveRecord::Observer

	observe Helpdesk::Ticket

	include Helpdesk::Ticketfields::TicketStatus

	def after_save(ticket)
		RAILS_DEFAULT_LOGGER.debug "INSIDE TICKET AFTER_SAVE OBSERVER "
		process_available_quests(ticket)
		rollback_achieved_quests(ticket)
	end

	private

	def process_available_quests(ticket)
		if ticket.responder and resolved_now?(ticket)
			ticket.responder.available_quests.ticket_quests.each do |quest|
				ticket.load_flexifield if quest.has_custom_field_filters?(ticket)
				is_a_match = quest.matches(ticket)
				start_time = Time.zone.now - quest.time_span unless quest.any_time_span?
				
				if is_a_match and evaluate_quest_query(quest,ticket,start_time,Time.zone.now)
					quest.award!(ticket.responder)
				end
			end
		end
	end

	def rollback_achieved_quests(ticket)
		if ticket.responder and reopened_now?(ticket)
			ticket.responder.quests.ticket_quests.each do |quest|
				badge_awarded_time = ticket.responder.badge_awarded_at(quest)
				quest_span_time = quest.time_span
				RAILS_DEFAULT_LOGGER.debug %(INSIDE ROLLBACK CASE 1
											 : #{badge_awarded_time} : span_time : #{quest_span_time.inspect})
				unless quest.any_time_span?
					ach_quest_start_time = badge_awarded_time - quest_span_time
					resolved_in_quest_span = ticket.ticket_states.resolved_at.between?(
						ach_quest_start_time,badge_awarded_time)
				else
					resolved_in_quest_span = ticket.ticket_states.resolved_at < badge_awarded_time
				end
				RAILS_DEFAULT_LOGGER.debug %(INSIDE ROLLBACK CASE 2 : resolved_in_quest_span : #{resolved_in_quest_span})
				if resolved_in_quest_span
					start_time = Time.zone.now - quest_span_time
					if (evaluate_quest_query(quest,ticket,ach_quest_start_time,badge_awarded_time) || 
							evaluate_quest_query(quest,ticket,start_time,Time.zone.now))
						ach_quest = ticket.responder.achieved_quest(quest)
						ach_quest.updated_at = Time.zone.now
						ach_quest.save
					else # Rollback points and badge
						RAILS_DEFAULT_LOGGER.debug %(ROLLBACK POINTS N BADGE of
											user_id : #{ticket.responder.id} : quest_id : #{quest.id})
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

	def evaluate_quest_query(quest, ticket, start_time, end_time)
		conditions = quest.filter_query
		f_criteria = quest.time_condition(start_time,end_time) + 
			' and helpdesk_tickets.responder_id = '+ticket.responder_id.to_s
		conditions[0] = conditions.empty? ? 
											f_criteria : (conditions[0] + ' and ' + f_criteria)
		resolv_tkts_in_time = quest_scoper(ticket.account).count(
			'helpdesk_tickets.id',
			:joins => %(inner join helpdesk_schema_less_tickets on helpdesk_tickets.id = 
							helpdesk_schema_less_tickets.ticket_id
              inner join helpdesk_ticket_states on helpdesk_tickets.id = 
              helpdesk_ticket_states.ticket_id and helpdesk_tickets.account_id = 
              helpdesk_ticket_states.account_id inner join users on 
              helpdesk_tickets.requester_id = users.id  and users.account_id = 
              helpdesk_tickets.account_id  left join customers on users.customer_id = 
              customers.id inner join flexifields on helpdesk_tickets.id = 
              flexifields.flexifield_set_id  and helpdesk_tickets.account_id = 
              flexifields.account_id and flexifields.flexifield_set_type = 'Helpdesk::Ticket'),
			:conditions => conditions)
		RAILS_DEFAULT_LOGGER.debug "Number of resolved tickets : #{resolv_tkts_in_time}"
		quest_achieved = resolv_tkts_in_time >= quest.quest_data[0][:value].to_i
	end

	def quest_scoper(account)
		account.tickets.visible.resolved_and_closed_tickets
	end
	
	def add_as_achieved_quest(quest, ticket)
		ach_quest = ticket.responder.achieved_quests.new(:user => ticket.responder,
								:quest => quest)
		ach_quest.account = ticket.account
		ach_quest.save
	end

end
