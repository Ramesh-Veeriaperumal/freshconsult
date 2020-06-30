module Ember
  module Tickets
    class ActivitiesController < ApiApplicationController
      include Helpdesk::Activities::ActivityMethods
      include TicketConcern
      include HelperConcern
      include AdvancedTicketScopes

      decorate_views

      before_filter :set_all_agent_groups_permission, :ticket_permission?, :load_ticket

      def index
        super
        response.api_meta = { count: @items_count } if @items_count.present?
      end

      private

        def load_ticket
          @ticket = current_account.tickets.find_by_param(params[:ticket_id], current_account)
          unless @ticket
            archive_ticket = current_account.archive_tickets.find_by_display_id(params[:ticket_id])
            (archive_ticket.present?) ? log_and_render_301_archive : log_and_render_404
          end
        end

        def log_and_render_301_archive
          redirect_to archive_ticket_link, status: 301
        end

        def archive_ticket_link
          path = "/api/_/tickets/archived/#{params[:ticket_id]}/activities" # not able to use the default rails_route_path.
          (archive_params.present?) ? "#{path}?#{archive_params}" : path
        end

        def archive_params
          include_params = params.select{|k,v| ActivityFilterConstants::PERMITTED_ARCHIVE_FIELDS.include?(k)}
          include_params.to_query
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
          @items = @collection.ticket_data
          @items_count = @collection.total_count
          add_field_mappings
        end

        def scoper
          current_account.tickets
        end

        def decorator_options
          super({ query_data_hash: @query_data_hash, ticket: @ticket })
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
