module Gamification
	module Quests
		module ProcessTicketQuests

			def evaluate_ticket_quests(ticket)
				return unless ticket.responder

				ticket.responder.available_quests.ticket_quests.each do |quest|
					ticket.load_flexifield if quest.has_custom_field_filters?(ticket)
					is_a_match = quest.matches(ticket)
				
					if is_a_match and evaluate_query(quest,ticket)
						quest.award!(ticket.responder)
					end
				end
			end

			def evaluate_query(quest, ticket, end_time=Time.zone.now)
				conditions = quest.filter_query
				f_criteria = quest.time_condition(end_time)
				conditions[0] = conditions.empty? ? f_criteria : (conditions[0] + ' and ' + f_criteria)
				
				resolv_tkts_in_time = quest_scoper(ticket.account, ticket.responder).count(
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

				quest_achieved = resolv_tkts_in_time >= quest.quest_data[0][:value].to_i
			end

			def quest_scoper(account, user)
				account.tickets.visible.assigned_to(user).resolved_and_closed_tickets
			end

		end
	end
end