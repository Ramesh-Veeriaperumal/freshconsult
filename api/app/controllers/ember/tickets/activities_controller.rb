module Ember
  module Tickets
    class ActivitiesController < ApiApplicationController
      include Helpdesk::Activities::ActivityMethods      
      include TicketConcern
      
      decorate_views
      
      skip_before_filter :check_privilege
      skip_before_filter :validate_filter_params
      before_filter :ticket_permission?, :load_ticket, :load_objects
      
      private

      def load_ticket
        @ticket = current_account.tickets.find_by_param(params[:ticket_id], current_account)
        log_and_render_404 unless @ticket
      end

      def load_objects
        @collection = fetch_activities({}, @ticket, :tkt_activity)
        if @collection === false || @collection.error_message.present?
          render_base_error(:internal_error, 500)
          return
          # TODO-EMBERAPI Come up with better errors
        end
        query_hash = @collection.members.present? ? JSON.parse(@collection.members).symbolize_keys : {}
        @additional_info  = parse_query_hash(query_hash, @ticket, false)
        @items = @collection.ticket_data
        more_additional_info
        # Rails.logger.debug "more_additional_info"
      end

      def decorator_options
        super({additional_info: @additional_info})
      end
      
      def more_additional_info
        @additional_info[:field_mapping] = Hash[*(
          current_account.ticket_fields_from_cache.collect{ |f| [f.name, f.label]}).flatten]
      end

    end
  end
end
