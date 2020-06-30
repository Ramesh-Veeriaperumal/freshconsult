module Ember
  module Search
    class TicketsController < SpotlightController
      include AdvancedTicketScopes

      def results
        @tracker = params[:context] == 'tracker'
        @recent_tracker = params[:context] == 'recent_tracker'

        if (params[:context] == 'merge' || @tracker) && params[:field]
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
        else
          @search_sort = params[:search_sort].presence
          @sort_direction = 'desc'
          if filter_params?
            @filter_params = params[:filter_params]
            @search_context = :filtered_ticket_search
          else
            @search_context = :agent_spotlight_ticket
          end
          @klasses = include_archive? ? ['Helpdesk::Ticket', 'Helpdesk::ArchiveTicket'] : ['Helpdesk::Ticket']
        end
        @items = esv2_query_results(esv2_agent_models)
        response.api_meta = { count: @items.total_entries }
        @items = [] if @count_request
        @items.reject!(&:nil?)
      end

      private

        def decorate_objects
          options = {}
          options[:name_mapping] = name_mapping
          sideload_options = ['requester', 'company']
          if params['include']
            sideload_options << params['include']
            options[:custom_fields_mapping] = Account.current.ticket_fields_name_type_mapping_cache if Account.current.field_service_management_enabled?
          end
          options[:sideload_options] = sideload_options.compact
          @items.map! { |item| TicketDecorator.new(item, options) } if @items
        end

        def name_mapping
          @name_mapping ||= cf_alias_mapping.each_with_object({}) { |(ff_alias, column), hash| hash[ff_alias] = TicketDecorator.display_name(ff_alias) }
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

            if filter_params?
              map_date if @filter_params[:created_at]
              sanitize_cf_params if @filter_params[:custom_fields].present?
              transformed_values = ::Search::KeywordSearch::Transform.new(@filter_params).transform
              es_params.merge!(transformed_values)
            end

            if transform_with_search_settings?
              transformed_values = ::Search::KeywordSearch::Transform.new(ticket_search_settings).transform_with_search_settings
              es_params.merge!(transformed_values)
            end

            unless @tracker || @recent_tracker || @skip_user_privilege
              if current_user.restricted?
                es_params[:restricted_responder_id] = current_user.id.to_i
                if current_user.group_ticket_permission
                  if advanced_scope_enabled? && params[:context] != 'merge'
                    es_params[:restricted_group_id] = current_user.all_associated_group_ids
                  else
                    es_params[:restricted_group_id] = current_user.associated_group_ids
                  end
                end

                if current_account.shared_ownership_enabled?
                  es_params[:restricted_internal_agent_id] = current_user.id.to_i
                  if current_user.group_ticket_permission
                    if advanced_scope_enabled? && params[:context] != 'merge'
                      es_params[:restricted_internal_group_id] = current_user.all_associated_group_ids
                    else
                      es_params[:restricted_internal_group_id] = current_user.associated_group_ids
                    end
                  end
                end
              end
            end

            unless (@search_sort.to_s == 'relevance') || @suggest
              es_params[:sort_by] = @search_sort
              es_params[:sort_direction] = @sort_direction
            end

            es_params[:size]  = @size
            es_params[:from]  = @offset
          end
        end

        def filter_params?
          params[:filter_params].present?
        end

        def map_date
          @filter_params[:created_at] = @filter_params[:created_at].to_i.days.ago.beginning_of_day.to_s
        end

        def cf_alias_mapping
          @cf_mapping ||= Account.current.ticket_field_def.ff_alias_column_mapping
        end

        def sanitize_cf_params
          @filter_params[:custom_fields].each_pair do |field, value|
            cf_name = cf_alias_mapping[field + "_#{Account.current.id}"]
            @filter_params.merge!(cf_name => value) if cf_name.present?
          end
          @filter_params.delete(:custom_fields)
        end

        def validate_results_param
          @search_validation = SearchTicketValidation.new(params)
          render_custom_errors(@search_validation, true) unless @search_validation.valid?
        end

        def search_settings?
          return false if @skip_user_privilege

          current_user.agent_preferences[:search_settings].present?
        end

        def ticket_search_settings
          current_user.agent_preferences[:search_settings][:tickets]
        end

        def transform_with_search_settings?
          [:agent_spotlight_ticket, :filtered_ticket_search].include?(@search_context) && search_settings?
        end

        def include_archive?
          return false unless current_account.features?(:archive_tickets)

          transform_with_search_settings? ? ticket_search_settings[:archive] : true
        end
    end
  end
end
