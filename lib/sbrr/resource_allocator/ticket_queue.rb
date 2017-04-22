module SBRR
  module ResourceAllocator
    class TicketQueue < Base

      def queue_aggregator
        SBRR::QueueAggregator::Ticket.new(user, options)
      end

      def pop_from_queue(queue)
        queue.pop_with_score
      end

      def get_item(item_id)
        tickets.find_by_display_id(item_id)
      end

      def assign_resource(item)
        is_assigned = SBRR::Assigner::User.new(item).assign
        SBRR.log "[SBRR::ResourceAllocator::Ticket] Trying to assign ticket:#{item.display_id} to user:#{user.try(:id)}, but assigned to user:#{item.responder_id}"
        if item.assigned?
          item.save
        end
        is_assigned    
      end

      private

        def tickets
          Account.current.tickets
        end

        def sbrr_queue_synchronizer(item)
          SBRR::Synchronizer::TicketUpdate::TicketQueue.new(item)
        end
    end
  end
end
