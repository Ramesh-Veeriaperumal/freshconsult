module SBRR
  module Synchronizer
    module TicketUpdate
      class TicketQueue < Base #used in ticket callbacks

        def sync
          if dequeue_from_old_ticket_queue?
            dequeue_from_old_ticket_queue
          end
          if enqueue_to_new_ticket_queue?
            enqueue_to_new_ticket_queue
          end
        end

        private

          def dequeue_from_old_ticket_queue?
            !new_ticket.sbrr_fresh_ticket && !new_ticket.sbrr_ticket_dequeued &&
              old_ticket.can_be_in_ticket_queue?
          end

          def enqueue_to_new_ticket_queue?
            new_ticket.can_be_in_ticket_queue?
          end

          def dequeue_from_old_ticket_queue
            SBRR.log "#{__method__} #{old_ticket.display_id}" 
            perform_in_queues old_queues, :dequeue_object_with_lock, old_ticket
          end

          def enqueue_to_new_ticket_queue
            SBRR.log "#{__method__} #{new_ticket.display_id}" 
            perform_in_queues new_queues, :enqueue_object_with_lock, new_ticket #lock not needed?
          end

          def queue_aggregator user, options
            QueueAggregator::Ticket.new user, options
          end

      end
    end
  end
end
