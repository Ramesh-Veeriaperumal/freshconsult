module Ember
  class TicketsController < ::TicketsController
    include DeleteSpamConcern

    INDEX_PRELOAD_OPTIONS = [:ticket_old_body, :schema_less_ticket, :flexifield, { requester: [:avatar, :flexifield, :default_user_company] }].freeze
    DEFAULT_TICKET_FILTER = :all_tickets.to_s.freeze
    def index
      super
      response.api_meta = { count: @items_count }
      # TODO-EMBERAPI Optimize the way we fetch the count
    end

    def create
      assign_protected
      ticket_delegator = TicketDelegator.new(@item, ticket_fields: @ticket_fields, custom_fields: params[cname][:custom_field], attachment_ids: @attachment_ids)
      if !ticket_delegator.valid?(:create)
        render_custom_errors(ticket_delegator, true)
      else
        @item.attachments = @item.attachments + ticket_delegator.draft_attachments if ticket_delegator.draft_attachments
        if @item.save_ticket
          @ticket = @item # Dirty hack. Should revisit.
          render_201_with_location(item_id: @item.display_id)
          notify_cc_people @cc_emails[:cc_emails] unless @cc_emails[:cc_emails].blank? || compose_email?
        else
          render_errors(@item.errors)
        end
      end
    end

    def bulk_execute_scenario
      bulk_action do
        return unless load_scenario
        Tickets::BulkScenario.perform_async(ticket_ids: @items.map(&:display_id), scenario_id: params[:scenario_id])
      end
    end

    def execute_scenario
      return unless load_scenario
      @va_rule.trigger_actions(@item, api_current_user)
      @item.save
      @item.create_scenario_activity(@va_rule.name)
      head 204
    end

    private

      def sanitize_params
        super
        # attachment_ids must be handled separately, should not be passed to build_object method
        if params[cname].key?(:attachment_ids)
          @attachment_ids = params[cname][:attachment_ids].map(&:to_i)
          params[cname].delete(:attachment_ids)
        end
      end

      def load_scenario
        @va_rule ||= current_account.scn_automations.find_by_id(params[:scenario_id])
        return true if @va_rule.present? && @va_rule.visible_to_me? && @va_rule.check_user_privilege
        render_errors(scenario_id: :"is invalid")
        false
      end

      def fetch_objects(items = scoper)
        @items = items.preload(preload_options).find_all_by_param(permissible_ticket_ids(params[cname][:ids]))
      end

      def preload_options
        if ApiTicketConstants::REQUIRE_PRELOAD.include?(action_name.to_sym)
          ApiTicketConstants::BULK_DELETE_PRELOAD_OPTIONS
        end
      end

      def permissible_ticket_ids(id_list)
        @permissible_ids ||= begin
          if api_current_user.can_view_all_tickets?
            id_list
          elsif api_current_user.group_ticket_permission
            tickets_with_group_permission(id_list)
          elsif api_current_user.assigned_ticket_permission
            tickets_with_assigned_permission(id_list)
          else
            []
          end
        end
      end

      def tickets_with_group_permission(ids)
        scoper.group_tickets_permission(api_current_user, ids).map(&:display_id)
      end

      def tickets_with_assigned_permission(ids)
        scoper.assigned_tickets_permission(api_current_user, ids).map(&:display_id)
      end

      def bulk_action_errors
        @bulk_action_errors ||=
          params[cname][:ids].inject({}) { |a, e| a.merge retrieve_error_code(e) }
      end

      def retrieve_error_code(id)
        if bulk_action_failed_items.include?(id)
          { id => :unable_to_perform }
        elsif !bulk_action_succeeded_items.include?(id)
          { id => :"is invalid" }
        else
          {}
        end
      end

      def bulk_action_succeeded_items
        @succeeded_ids ||= @items.map(&:display_id) - bulk_action_failed_items
      end

      def bulk_action_failed_items
        @failed_ids ||= (@items_failed || []).map(&:display_id)
      end

      def update?
        @update ||= current_action?('update') || current_action?('execute_scenario')
      end

      def decorate_objects
        return if @error_ticket_filter.present?
        decorator, options = decorator_options
        @requester_collection = @items.collect(&:requester).uniq
        @requesters = @requester_collection.map { |contact| ContactDecorator.new(contact, name_mapping: contact_name_mapping) }

        @items.map! { |item| decorator.new(item, options) }
      end

      def contact_name_mapping
        # will be called only for index and show.
        # We want to avoid memcache call to get custom_field keys and hence following below approach.
        custom_field = index? ? @requester_collection.first.try(:custom_field) : @requester.custom_field
        custom_field.each_with_object({}) { |(name, value), hash| hash[name] = CustomFieldDecorator.display_name(name) } if custom_field
      end

      def tickets_filter
        return if @error_ticket_filter.present?
        current_account.tickets.permissible(api_current_user).filter(params: params, filter: 'Helpdesk::Filters::CustomTicketFilter')
      end

      def validate_filter_params
        # This is a temp filter validation.
        # Basically overriding validation and fetching any filter available
        # This is going to handle Default ticket filters and custom ticket filters.
        # ?email=** or ?requester_id=*** are NOT going to be supported as of now.
        # Has to be taken up post sprint while cleaning this up and writing a proper validator for this
        params.permit(*ApiTicketConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS, :query_hash, :order, :order_by)
        params[:filter] ||= DEFAULT_TICKET_FILTER
        if params[:filter].to_i.to_s == params[:filter] # Which means it is a string
          @ticket_filter = current_account.ticket_filters.find_by_id(params[:filter])
          if @ticket_filter.nil? || !@ticket_filter.has_permission?(api_current_user)
            render_filter_errors
          else
            params.merge!(@ticket_filter.attributes['data'])
          end
        elsif params[:query_hash].present?
          params[:wf_model] = 'Helpdesk::Ticket'
          params[:data_hash] = QueryHash.new(params[:query_hash].values).to_system_format
          params.delete(:filter)
        elsif Helpdesk::Filters::CustomTicketFilter::DEFAULT_FILTERS.keys.include?(params[:filter])
          @ticket_filter = current_account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME).default_filter(params[:filter])
          params["filter_name"] = params[:filter]
        else
          render_filter_errors
        end
        params[:wf_order] = params[:order_by]
        params[:wf_order_type] = params[:order]
      end
      
      def order_clause
        nil
      end

      def render_filter_errors
        # This is just force filter errors
        # Always expected to render errors
        @error_ticket_filter = ::TicketFilterValidation.new(params, nil, string_request_params?)
        render_errors(@error_ticket_filter.errors, @error_ticket_filter.error_options) unless @error_ticket_filter.valid?
      end

      def conditional_preload_options
        INDEX_PRELOAD_OPTIONS
      end

      def sideload_options
        [:requester, :stats]
      end

      def render_201_with_location(template_name: "tickets/#{action_name}", location_url: 'ticket_url', item_id: @item.id)
        render template_name, location: send(location_url, item_id), status: 201
      end

      wrap_parameters(*wrap_params)
  end
end
