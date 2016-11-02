module Ember
  class TicketsController < ::TicketsController
    include DeleteSpamConcern
    include TicketConcern
    include HelperConcern
    include SplitNoteHelper

    INDEX_PRELOAD_OPTIONS = [:ticket_old_body, :schema_less_ticket, :flexifield, { requester: [:avatar, :flexifield, :default_user_company] }].freeze
    DEFAULT_TICKET_FILTER = :all_tickets.to_s.freeze

    before_filter :ticket_permission?, only: [:latest_note, :split_note]
    before_filter :load_note, only: [:split_note]

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

    def bulk_update
      bulk_action do
        original_params_hash = params[cname][:properties].deep_dup
        return unless validate_bulk_update_params
        @items_failed = []
        @validation_errors = {}
        @items.each do |item|
          unless validate_update_params(item, :update)
            @items_failed << item
            @validation_errors.merge!(item.display_id => @ticket_validation)
          end
        end
        items_to_update = @items - @items_failed
        execute_bulk_update_action(items_to_update) unless update_in_background?(items_to_update, original_params_hash)
        params[cname][:ids] = @ticket_ids
      end
    end

    def bulk_execute_scenario
      return unless validate_body_params
      sanitize_body_params
      @delegator_klass = 'ScenarioDelegator'
      return unless validate_delegator(@item, { scenario_id: params[cname][:scenario_id] })
      fetch_objects
      ::Tickets::BulkScenario.perform_async(ticket_ids: @items.map(&:display_id), scenario_id: params[cname][:scenario_id])
      render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
    end

    def execute_scenario
      return unless validate_body_params
      @delegator_klass = 'ScenarioDelegator'
      return unless validate_delegator(@item, { scenario_id: params[cname][:scenario_id] })
      va_rule = @delegator.va_rule
      va_rule.trigger_actions(@item, api_current_user)
      @item.save
      #TODO-LongTerm create_scenario_activity should ideally be inside va_rule model and not in the controllers
      @item.create_scenario_activity(va_rule.name)
      head 204
    end

    def latest_note
      @note = @item.conversation.first
      head(204) and return if @note.nil?
      @user = ContactDecorator.new(@note.user, {})
    end

    def split_note
      split_the_note
      if @new_ticket.errors.present?
        render_errors(@new_ticket.errors)
      else
        options = { name_mapping: (@name_mapping || get_name_mapping), sideload_options: [] }
        @item = TicketDecorator.new(@new_ticket, options)
        render '/tickets/show'
      end
    end

    private

      # code duplicated - validate_params method of API Tickets controller
      def process_request_params
        @ticket_ids = params[cname][:ids]
        params[cname] = params[cname][:properties]
        # We are obtaining the mapping in order to swap the field names while rendering(both successful and erroneous requests), instead of formatting the fields again.
        @ticket_fields = Account.current.ticket_fields_from_cache
        @name_mapping = TicketsValidationHelper.name_mapping(@ticket_fields) # -> {:text_1 => :text}
        # Should not allow any key value pair inside custom fields hash if no custom fields are available for accnt.
        custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
        params[cname].permit(*(ApiTicketConstants::BULK_UPDATE_FIELDS | ['custom_fields' => custom_fields]))
        set_default_values
        @params_hash = params[cname].merge(statuses: Helpdesk::TicketStatus.status_objects_from_cache(current_account), ticket_fields: @ticket_fields)
      end

      def validate_update_params(item, validation_context)
        @ticket_validation = TicketValidation.new(@params_hash, item, string_request_params?)
        @ticket_validation.valid?(validation_context)
      end

      def validate_bulk_update_params
        process_request_params
        unless validate_update_params(nil, :bulk_update)
          render_custom_errors(@ticket_validation, true)
          return false
        end
        sanitize_params
        @item = current_account.tickets.new
        assign_attributes_for_update
        ticket_delegator = TicketDelegator.new(@item, ticket_fields: @ticket_fields, custom_fields: @custom_fields)
        unless ticket_delegator.valid?(:bulk_update)
          render_custom_errors(ticket_delegator, true)
          return false
        end
        true
      end

      def sanitize_params
        super
        # attachment_ids must be handled separately, should not be passed to build_object method
        if params[cname].key?(:attachment_ids)
          @attachment_ids = params[cname][:attachment_ids].map(&:to_i)
          params[cname].delete(:attachment_ids)
        end
      end

      def fetch_objects(items = scoper)
        @items = items.preload(preload_options).find_all_by_param(permissible_ticket_ids(params[cname][:ids]))
      end

      def preload_options
        if ApiTicketConstants::REQUIRE_PRELOAD.include?(action_name.to_sym)
          ApiTicketConstants::BULK_DELETE_PRELOAD_OPTIONS
        end
      end

      def execute_bulk_update_action(items)
        items.each do |item|
          @item = item
          assign_attributes_for_update
          @items_failed << item unless @item.update_ticket_attributes(params[cname])
        end
      end

      # code duplicated - update method of API Tickets controller
      def assign_attributes_for_update
        assign_protected
        # Assign attributes required as the ticket delegator needs it.
        @custom_fields = params[cname][:custom_field] # Assigning it here as it would be deleted in the next statement while assigning.
        @delegator_attributes ||= validatable_delegator_attributes
        @item.assign_attributes(@delegator_attributes)
        @item.assign_description_html(params[cname][:ticket_body_attributes]) if params[cname][:ticket_body_attributes]
      end

      def update_in_background?(items, params_hash)
        return false if items.length <= ApiTicketConstants::BACKGROUND_THRESHOLD
        tags = params_hash.delete(:tags)
        args = { "action" => :update_multiple, "helpdesk_ticket" => params_hash }
        args.merge!({"ids" => items.map(&:display_id)})
        args[:tags] = tags.join(',') unless tags.nil?
        ::Tickets::BulkTicketActions.perform_async(args)
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
          params[cname][:ids].inject([]) do |a, e|
            error_hash = retrieve_error_code(e)
            error_hash.any? ? a << error_hash : a
          end
      end

      def retrieve_error_code(id)
        ret_hash = { :id => id, :errors => {}, :error_options => {} }
        if bulk_action_failed_items.include?(id)
          if @validation_errors && @validation_errors.key?(id)
            ret_hash[:validation_errors] = @validation_errors[id]
          else
            ret_hash[:errors].merge!({:id => :unable_to_perform })
          end
        elsif !bulk_action_succeeded_items.include?(id)
          ret_hash[:errors].merge!({:id => :"is invalid" })
        else
          return {}
        end
        return ret_hash
      end

      def bulk_action_succeeded_items
        @succeeded_ids ||= @items.map(&:display_id) - bulk_action_failed_items
      end

      def bulk_action_failed_items
        @failed_ids ||= (@items_failed || []).map(&:display_id)
      end

      def decorate_objects
        return if @error_ticket_filter.present?
        decorator, options = decorator_options
        
        if sideload_options.include?('requester')
          @requesters = @items.collect(&:requester).uniq.each_with_object({}) do |contact, hash| 
            hash[contact.id] = ContactDecorator.new(contact, name_mapping: contact_name_mapping)
          end
        end

        @items.map! { |item| decorator.new(item, options) }
      end

      def contact_name_mapping
        @contact_name_mapping ||= begin
          custom_field = index? ? User.new.custom_field : @requester.custom_field
          custom_field.each_with_object({}) { |(name, value), hash| hash[name] = CustomFieldDecorator.display_name(name) } if custom_field
        end
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
        ApiTicketConstants::SIDE_LOADING & (params[:include] || '').split(',').map!(&:strip)
      end

      def constants_class
        :ApiTicketConstants.to_s.freeze
      end

      def render_201_with_location(template_name: "tickets/#{action_name}", location_url: 'ticket_url', item_id: @item.id)
        render template_name, location: send(location_url, item_id), status: 201
      end

      def load_note
        @note = @item.notes.find_by_id(params[:note_id])
        log_and_render_404 unless @note
      end

      wrap_parameters(*wrap_params)
  end
end
