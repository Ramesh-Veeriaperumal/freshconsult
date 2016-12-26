module SBRR
  module Assigner
    class User < Base

      def ticket
        @ticket ||= new_ticket
      end

      def do_assign
        _next_agent = next_agent
        SBRR.log "Got next agent #{_next_agent && _next_agent.id} for ticket #{ticket.display_id}" 
        if _next_agent
          ticket.responder     = _next_agent
          ticket.model_changes = ticket.merge_changes ticket.model_changes, ticket.changes.slice(:responder_id)
          ticket.set_round_robin_activity
          ticket.sbrr_user_score_incremented = true
        end
      end

      def can_assign?
        ticket.can_be_in_ticket_queue?
      end

      def next_agent
        begin
          user_id, score = queue.top #checking top here to generate relevant queues
          SBRR.log "TOP USER #{user_id}, #{"%16d" % score.to_i}" 
          user = Account.current.users.find_by_id(user_id) if user_id
          is_user_eligible = user_id && user &&
            (no_of_tickets_assigned(score) < group.capping_limit) && 
              group.skill_based_round_robin_enabled? &&
                user.match_sbrr_conditions?(ticket) && user.agent.available

          if is_user_eligible
            SBRR.log "same_agent? #{user_id.to_i == old_ticket.responder_id} model_changes #{ticket.model_changes.inspect} old_ticket.can_account_for_user_score? #{old_ticket.can_account_for_user_score?} !ticket.has_user_queue_changes? #{!ticket.has_user_queue_changes?} !ticket.has_round_robin_eligibility_changes? #{!ticket.has_round_robin_eligibility_changes?}" 
            if user_id.to_i == old_ticket.responder_id && #after unassignment, if same user is at the top
                old_ticket.can_account_for_user_score? && !ticket.has_round_robin_eligibility_changes?
              SBRR.log "returning #{user_id} without popping/incrementing" 
              return user #unassign-reassign same user, model_changes[:responder_id] will become nil, hence no decr-incr
            end
            relevant_queues = relevant_queues(user)
            right_queue     = right_queue(relevant_queues)
            user_id         = right_queue.pop_if_within_capping_limit user, group.capping_limit, relevant_queues
            return user if user_id
          end 
        end until !is_user_eligible # should there be a max retry? as users will always be in the queue? - Hari
        return nil
      end

      def queue #used only to find top
        @queue ||= SBRR::Queue::User.new account_id, group_id, skill_id
      end

      #finding this among relevant queues, because relevant queues share the score calculator
      def right_queue(_queues)
        _queues.find{|q| q.skill_id == skill_id}
      end

      #finding relevant queues after fetching user, so that we dont enqueue him in the wrong queue where he is not present
      def relevant_queues _user
        @relevant_queues = queue_aggregator(_user).relevant_queues
      end

      def no_of_tickets_assigned(score)
        ScoreCalculator::User.new(group, score).old_assigned_tickets_in_group
      end

      def queue_aggregator(_user)
        QueueAggregator::User.new _user, :group => group
      end

    end
  end
end