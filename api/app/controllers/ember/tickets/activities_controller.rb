module Ember
  module Tickets
    class ActivitiesController < ApiApplicationController
      include Helpdesk::Activities::ActivityMethods
      include TicketConcern
      include HelperConcern

      decorate_views

      skip_before_filter :check_privilege
      before_filter :ticket_permission?, :load_ticket

      def index
        super
        response.api_meta = { count: @items_count } if @items_count.present?
      end

      private

        def load_ticket
          @ticket = current_account.tickets.find_by_param(params[:ticket_id], current_account)
          log_and_render_404 unless @ticket
        end

        def validate_filter_params
          @constants_klass = 'ActivityFilterConstants'
          @validation_klass = 'ActivityFilterValidation'
          validate_query_params
        end

        def constants_class
          :ActivityFilterConstants.to_s.freeze
        end

        def load_objects
          @collection = fetch_activities(pagination_params, @ticket)
          if @collection == false || @collection.error_message.present?
            render_base_error(:internal_error, 500)
            return
            # TODO-EMBERAPI Come up with better errors
          end
          query_hash = @collection.members.present? ? JSON.parse(@collection.members).symbolize_keys : {}
          @query_data_hash = parse_query_hash(query_hash, @ticket, false)
          @query_data_hash[:ticket] = @ticket
          @items = @collection.ticket_data
          @items_count = @collection.total_count
          add_field_mappings
        end

        def decorator_options
          super({ query_data_hash: @query_data_hash })
        end

        def add_field_mappings
          @query_data_hash[:field_mapping] = Hash[*(
            current_account.ticket_fields_from_cache.collect { |f| [f.name, f.label] }).flatten]
        end

        def pagination_params
          params.slice(:since_id, :before_id, :limit)
        end
    end
  end
end
