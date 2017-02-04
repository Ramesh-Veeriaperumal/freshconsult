# Have to handle archived tickets too

module Ember
  module Search
    class TicketsController < SpotlightController

      def results
        @tracker = params[:context] == 'tracker'
        @recent_tracker = params[:context] == 'recent_tracker'

        if params[:context] == 'spotlight'
          @search_context = :agent_spotlight_ticket
          @klasses = ['Helpdesk::Ticket', 'Helpdesk::ArchiveTicket']
        elsif (params[:context] == 'merge' || @tracker) && params[:field]
          @search_field = params[:field]
          @klasses = ['Helpdesk::Ticket']

          @search_context = case @search_field
            when 'display_id'
              @search_sort = 'display_id'
              @sort_direction = 'asc'
              @tracker ? :assoc_tickets_display_id : :merge_display_id
            when 'subject'
              @search_sort = 'created_at'
              @sort_direction = 'desc'
              @tracker ? :assoc_tickets_subject : :merge_subject
            when 'requester'
              @search_sort = 'created_at'
              @sort_direction = 'desc'
              @requester_ids = params[:requester_ids] if params[:requester_ids].present?
              @tracker ? :assoc_tickets_requester : :merge_requester
            end
        elsif @recent_tracker
          @search_sort      = 'created_at'
          @sort_direction   = 'desc'
          @search_context = :assoc_recent_trackers
          @klasses = ['Helpdesk::Ticket', 'Helpdesk::ArchiveTicket']
        end

        @items = esv2_query_results(esv2_agent_models)
        response.api_meta = { count: @items.count }
      end

      private

        def decorator_options
          super({ name_mapping: Account.current.ticket_field_def.ff_alias_column_mapping.each_with_object({}) { |(ff_alias, column), hash| hash[ff_alias] = TicketDecorator.display_name(ff_alias) } })
        end

        def construct_es_params
          super.tap do |es_params|
            es_params[:requester_ids] = @requester_ids if @requester_ids

            if @tracker || @recent_tracker
              es_params[:association_type]  = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:tracker]
              es_params[:exclude_status]    = [
                Helpdesk::Ticketfields::TicketStatus::CLOSED, Helpdesk::Ticketfields::TicketStatus::RESOLVED
              ] #=> will be consumed for recent trackers only
            end

            if current_user.restricted?
              es_params[:restricted_responder_id] = current_user.id.to_i
              es_params[:restricted_group_id] = current_user.agent_groups.map(&:group_id) if current_user.group_ticket_permission
            end

            unless (@search_sort.to_s == 'relevance') || @suggest
              es_params[:sort_by] = @search_sort
              es_params[:sort_direction] = @sort_direction
            end

            es_params[:size]  = @size
            es_params[:from]  = @offset
          end
        end
    end
  end
end
