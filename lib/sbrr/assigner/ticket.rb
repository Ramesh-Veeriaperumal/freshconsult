module SBRR
  module Assigner
    class Ticket < Base

      def ticket
        @ticket ||= old_ticket
      end

      def do_assign
        _next_ticket = next_ticket
        SBRR.log "Got next ticket #{_next_ticket && _next_ticket.display_id} for agent #{user.id} while freed from #{ticket && ticket.display_id}" 
        if _next_ticket
          _next_ticket.responder = user
          _next_ticket.set_round_robin_activity
          _next_ticket.sbrr_ticket_dequeued = true
          user_queues.each{|queue| queue.increment_object_with_lock user} #hack to avoid race during bulk action group change
          _next_ticket.sbrr_user_score_incremented = true
          assigned = _next_ticket.save
        end
        [assigned, _next_ticket]
      end

      def can_assign?
        if user && user.sbrr_fresh_user
          SBRR.log "Fresh user #{user.id}" 
          user_has_not_reached_capping_limit?
        else 
          !ticket.sbrr_fresh_ticket &&
            ticket.can_account_for_user_score? && group.skill_based_round_robin_enabled? &&
              user_has_not_reached_capping_limit?
        end
      end

      def next_ticket
        queues.each do |queue|
          begin
            display_id, score = *queue.pop
            if display_id
              SBRR.log "popped Ticket ##{display_id}" 
              _ticket = Account.current.tickets.find_by_display_id(display_id)
              SBRR.log "popped Ticket ##{_ticket.inspect}" 
              if _ticket && _ticket.can_be_in_ticket_queue? 
                if _ticket.match_sbrr_conditions?(user)
                  return _ticket
                else
                  #in wrong queue, push it to the right queue?
                end
              end#discards poped object as its not eligible for sbrr
            end
          end until display_id.nil? #retries to pop the next ticket from preferred skill queue until its empty
        end
        return nil
      end

      def queues
        queue_aggregator.relevant_queues
      end

      def queue_aggregator
        QueueAggregator::Ticket.new user, :group => group
      end

      def user_queues
        user_queue_aggregator.relevant_queues
      end

      def user_queue_aggregator
        QueueAggregator::User.new user, :group => group
      end

      def user_has_not_reached_capping_limit?
        tickets_count = user.no_of_assigned_tickets(group)
        tickets_count && tickets_count < group.capping_limit    
      end
      
  end
end
