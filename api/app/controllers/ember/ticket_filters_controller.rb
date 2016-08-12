module Ember
  class TicketFiltersController < ApiApplicationController
    skip_before_filter :check_privilege

    def index
      load_objects
      append_default_filters
    end

    private

      def load_objects
        @items = scoper.collect do |filter|
          filter.attributes.slice('id', 'name').merge(default: false)
        end
      end

      def scoper
        current_account.ticket_filters.my_ticket_filters(api_current_user)
      end

      def append_default_filters
        @items |= TicketsFilter.default_views
      end
  end
end
