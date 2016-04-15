module Gamification
  class ProcessTicketQuests < BaseWorker

    def perform(args)
      args.symbolize_keys!
      account_id = args[:account_id]
      Account.reset_current_account
      Sharding.select_shard_of(account_id) do
        account = Account.find(account_id)
        account.make_current
        args.key?(:rollback) ? rollback_ticket_quests(args[:id], args[:account_id], args[:resolved_time_was]) : evaluate_ticket_quests(args[:user_id])
      end
    end

    def evaluate_ticket_quests(user_id)
      return unless user_id
      user = User.find_by_id(user_id)
      user.available_quests.ticket_quests.each do |quest|
        if quest_achieved?(quest,user)
          quest.award!(user)
        end
      end
    end

    def quest_achieved?(quest, user, end_time=Time.zone.now)
      conditions = quest.filter_query
      f_criteria = quest.time_condition(end_time)
      conditions[0] = conditions.empty? ? f_criteria : (conditions[0] + ' and ' + f_criteria)
      joins = ''
      joins << %(inner join helpdesk_schema_less_tickets on helpdesk_tickets.id = helpdesk_schema_less_tickets.ticket_id and helpdesk_tickets.account_id = helpdesk_schema_less_tickets.account_id ) unless conditions[0].index('helpdesk_schema_less_tickets').nil?
      joins << %(inner join helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and helpdesk_tickets.account_id = helpdesk_ticket_states.account_id ) unless conditions[0].index('helpdesk_ticket_states').nil?
      joins << %(inner join flexifields on helpdesk_tickets.id = flexifields.flexifield_set_id  and helpdesk_tickets.account_id = flexifields.account_id and flexifields.flexifield_set_type = 'Helpdesk::Ticket' ) unless conditions[0].index('flexifields').nil?
      resolv_tkts_in_time = Sharding.run_on_slave { quest_scoper(user.account, user).count(
        'helpdesk_tickets.id',
        :joins => joins,
        :conditions => conditions) }

      quest_achieved = resolv_tkts_in_time >= quest.quest_data[0][:value].to_i
    end

    def quest_scoper(account, user)
      account.tickets.visible.assigned_to(user).resolved_and_closed_tickets
    end

    def rollback_ticket_quests(id, account_id, old_resolv_time)

    	ticket = Account.current.tickets.find_by_id(id)
      return if !ticket or ticket.spam or ticket.deleted or !ticket.responder
      
      ticket.responder.quests.ticket_quests.each do |quest|
        badge_awarded_time = ticket.responder.badge_awarded_at(quest)


        resolved_in_quest_span = if !old_resolv_time.blank?
          old_resolv_time = Time.zone.parse(old_resolv_time.to_s)
          unless quest.any_time_span?
            old_resolv_time.between?(quest.start_time(badge_awarded_time), badge_awarded_time)
          else
            old_resolv_time <= badge_awarded_time
          end
        else
          true
        end
        
        if resolved_in_quest_span
          if (quest_achieved?(quest,ticket,badge_awarded_time) || quest_achieved?(quest,ticket))
            ach_quest = ticket.responder.achieved_quest(quest)
            ach_quest.updated_at = Time.zone.now
            ach_quest.save
          else # Rollback points and badge
            Rails.logger.debug %(ROLLBACK POINTS N BADGE of user_id : #{ticket.responder.id} 
                  : quest_id : #{quest.id})
            quest.revoke!(ticket.responder)
          end
        end
      end
    end
  end
end