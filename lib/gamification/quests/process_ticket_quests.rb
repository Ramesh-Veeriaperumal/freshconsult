module Gamification
	module Quests
		class ProcessTicketQuests < Resque::Job
			@queue = "gamificationQueue"

			def self.perform(args)
				args.symbolize_keys!
				id, account_id = args[:id], args[:account_id]
				ticket = Helpdesk::Ticket.find_by_id_and_account_id(id, account_id)
				return if ticket.deleted or ticket.spam
				args.key?(:rollback) ? rollback_ticket_quests(ticket, args[:resolved_time_was]) : evaluate_ticket_quests(ticket)
			end

			def self.evaluate_ticket_quests(ticket)
				return unless ticket.responder

				ticket.responder.available_quests.ticket_quests.each do |quest|
					ticket.load_flexifield if quest.has_custom_field_filters?(ticket)
					is_a_match = quest.matches(ticket)
				
					if is_a_match and evaluate_query(quest,ticket)
						quest.award!(ticket.responder)
					end
				end
			end

			def self.evaluate_query(quest, ticket, end_time=Time.zone.now)
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

			def self.quest_scoper(account, user)
				account.tickets.visible.assigned_to(user).resolved_and_closed_tickets
			end

			def self.rollback_ticket_quests(ticket, old_resolv_time)
				ticket.responder.quests.ticket_quests.each do |quest|
				badge_awarded_time = ticket.responder.badge_awarded_at(quest)

				if !old_resolv_time.blank?
					old_resolv_time = Time.zone.parse(old_resolv_time.to_s)
					unless quest.any_time_span?
						resolved_in_quest_span = old_resolv_time.between?(
							quest.start_time(badge_awarded_time), badge_awarded_time)
					else
						resolved_in_quest_span = old_resolv_time <= badge_awarded_time
					end
				else
					resolved_in_quest_span = true
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
	end
end