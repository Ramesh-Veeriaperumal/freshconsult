module SBRR
  module Synchronizer
    module TicketUpdate
      class Base

        attr_reader :new_ticket, :old_ticket, :score_calculator, :current_ticket

        def initialize _ticket, options={}
          @current_ticket = _ticket
          @old_ticket = _ticket.ticket_was _ticket.model_changes, _ticket.sbrr_state_attributes, TicketConstants::SKILL_BASED_TICKET_ATTRIBUTES
          @new_ticket = _ticket.ticket_is _ticket.model_changes, _ticket.sbrr_state_attributes, TicketConstants::SKILL_BASED_TICKET_ATTRIBUTES
        end

        private

          def perform_in_queues _queues, operation, _ticket
            _queues.each{ |_queue| _queue.send(operation, _ticket) }
          end

          def refresh_in_queues _queues, operation, _ticket, score = nil
            _queues.each{ |_queue| _queue.send(operation, _ticket, score) }
          end

          def old_queues
            @old_queues ||= queues queue_details old_ticket
          end

          def new_queues
            @new_queues ||= queues queue_details new_ticket
          end

          def queue_details ticket
            [ticket.responder, {:group => ticket.group, :skill => ticket.skill}]
          end

          def queues args
            queue_aggregator(*args).relevant_queues
          end

      end
    end
  end
end
