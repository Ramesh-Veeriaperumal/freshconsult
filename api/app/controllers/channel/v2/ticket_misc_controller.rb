module Channel::V2
  # To list tickets based on selected filter
  class TicketMiscController < ::Ember::TicketsController
    def self.decorator_name
      'TicketDecorator'.constantize
    end

    private

      def ticket_filter_delegator_class
        'Channel::V2::TicketFilterDelegator'
      end

      def ticket_filter_validation_class
        'Channel::V2::TicketFilterValidation'
      end

      def ticket_filter_constant_class
        'Channel::V2::TicketFilterConstants'
      end
  end
end
