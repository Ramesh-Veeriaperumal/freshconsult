require "helpdesk/ticket"

class TicketObserver < ActiveRecord::Observer

	observe Helpdesk::Ticket

	include Helpdesk::Ticketfields::TicketStatus

	def after_save(ticket)
		RAILS_DEFAULT_LOGGER.debug "$$$$$$$$$$$$$$$$$$$$$$$$$$ "
		RAILS_DEFAULT_LOGGER.debug "INSIDE AFTER_SAVE OBSERVER "
		if ticket.responder and resolved_now?(ticket)
			available_quests(ticket).each do |quest|
				ticket.load_flexifield if quest.has_custom_field_filters?(ticket)
				is_a_match = quest.matches(ticket)
				if is_a_match and evaluate_quest_query(quest,ticket)
					add_as_achieved_quest(quest, ticket)
					add_reward_points(quest, ticket)
				end
			end
		end
	end

	private

	def resolved_now?(ticket)
		ticket.status_changed? && ((ticket.resolved? && ticket.status_was != CLOSED) ||
			(ticket.closed? && ticket.status_was != RESOLVED))
	end

	def reopened_now?(ticket)
		ticket.status_changed? && (ticket.active? && 
			[RESOLVED, CLOSED].include?(ticket.status_was))
	end

	def available_quests(ticket)
		ticket.account.quests.available(ticket.responder)
	end

	def evaluate_quest_query(quest,ticket)
		conditions = quest.filter_query
		f_criteria = quest.time_condition(ticket.account) + 
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

	def add_reward_points(quest,ticket)
		RAILS_DEFAULT_LOGGER.debug "INSIDE ADD_REWARD_POINTS "
		SupportScore.add_ticket_score(ticket, quest.points)
	end


end
