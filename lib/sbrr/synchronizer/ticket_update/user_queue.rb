module SBRR
  module Synchronizer
    module TicketUpdate
      class UserQueue < Base #used in ticket callbacks

        def sync
          if decrement_scores_in_old_user_queues?
            decrement_scores_in_old_user_queues
          end
          if increment_scores_in_new_user_queues?
            increment_scores_in_new_user_queues 
          end
        end

        private

          def decrement_scores_in_old_user_queues?
            !new_ticket.sbrr_fresh_ticket && old_ticket.can_account_for_user_score?
          end

          def increment_scores_in_new_user_queues?
            !new_ticket.sbrr_user_score_incremented && new_ticket.can_account_for_user_score? 
          end

          def decrement_scores_in_old_user_queues
            SBRR.log "#{__method__} #{old_ticket.responder && old_ticket.responder.id} for ticket #{old_ticket.display_id}" 
            perform_in_queues old_queues, :decrement_object_with_lock, old_ticket.responder
          end

          def increment_scores_in_new_user_queues
            SBRR.log "#{__method__} #{new_ticket.responder && new_ticket.responder.id} for ticket #{new_ticket.display_id}" 
            perform_in_queues new_queues, :increment_object_with_lock, new_ticket.responder
          end

          def queue_aggregator user, options
            QueueAggregator::User.new user, options.except(:skill)
          end

      end
    end
  end
end
