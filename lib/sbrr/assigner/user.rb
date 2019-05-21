module SBRR
  module Assigner
    class User < Base

      MAX_NEXT_AGENT_RETRY = 5

      def ticket
        @ticket ||= new_ticket
      end

      def do_assign
        _next_agent = next_agent
        SBRR.log "Got next agent #{_next_agent && _next_agent.id} for ticket #{ticket.display_id}" 
        if _next_agent
          current_ticket.responder     = _next_agent
          current_ticket.model_changes = ticket.merge_changes ticket.model_changes, ticket.changes.slice(:responder_id)
          current_ticket.set_round_robin_activity
          current_ticket.sbrr_user_score_incremented = true
          ticket_queues.each {|q| q.dequeue_object_with_lock current_ticket}
          current_ticket.sbrr_ticket_dequeued = true
          assigned = true
        end
        [assigned, _next_agent]
      end

      def can_assign?
        ticket.can_be_in_ticket_queue?
      end

      def next_agent
        is_user_eligible = true
        count = 0
        while is_user_eligible && count < MAX_NEXT_AGENT_RETRY
          user_id, score = queue.top #checking top here to generate relevant queues
          SBRR.log "TOP USER #{user_id}, #{"%16d" % score.to_i}" 
          user = Account.current.users.find_by_id(user_id) if user_id
          conditions_matched = user.match_sbrr_conditions?(ticket) if user
          is_user_eligible = user_id && user &&
            (no_of_tickets_assigned(score) < group.capping_limit) && 
              group.skill_based_round_robin_enabled? &&
                conditions_matched && user.agent.available
          if is_user_eligible
            relevant_queues = relevant_queues(user)
            right_queue     = right_queue(relevant_queues)
            user_id         = right_queue.pop_if_within_capping_limit user, group.capping_limit, relevant_queues
            return user if user_id
          else
            SBRR.log "USER :: #{user_id} #{user && user.id}, is_user_eligible :: false, #{group.capping_limit}, #{conditions_matched.inspect}, #{user && user.agent && user.agent.available.inspect}"
          end
          queue.dequeue_object_with_lock user if !conditions_matched && user
          count = count + 1
        end
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

      def ticket_queues
        ticket_queue_aggregator.relevant_queues
      end

      def ticket_queue_aggregator
        QueueAggregator::Ticket.new nil, {:group => group, :skill => skill}
      end

    end
  end
end
