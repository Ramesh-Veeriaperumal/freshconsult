module Ember
  class TicketsController < ::TicketsController
    include BulkActionConcern
    include TicketConcern
    include HelperConcern
    include SplitNoteHelper
    include AttachmentConcern

    INDEX_PRELOAD_OPTIONS = [:tags, :ticket_old_body, :schema_less_ticket, :flexifield, { requester: [:avatar, :flexifield, :default_user_company] }].freeze
    DEFAULT_TICKET_FILTER = :all_tickets.to_s.freeze

    before_filter :ticket_permission?, only: [:latest_note, :split_note]
    before_filter :load_note, only: [:split_note]

    def index
      sanitize_filter_params
      @delegator_klass = 'TicketFilterDelegator'
      return unless validate_delegator(nil, params)
      assign_filter_params
      super
      response.api_meta = { count: @items_count }
      # TODO-EMBERAPI Optimize the way we fetch the count
    end

    def create
      assign_protected
      delegator_hash = { ticket_fields: @ticket_fields, custom_fields: params[cname][:custom_field],
                         attachment_ids: @attachment_ids, shared_attachments: shared_attachments }
      return unless validate_delegator(@item, delegator_hash)
      save_ticket_and_respond
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
      return unless validate_delegator(@item, scenario_id: params[cname][:scenario_id])
      fetch_objects
      ::Tickets::BulkScenario.perform_async(ticket_ids: @items.map(&:display_id), scenario_id: params[cname][:scenario_id])
      render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
    end

    def execute_scenario
      return unless validate_body_params
      @delegator_klass = 'ScenarioDelegator'
      return unless validate_delegator(@item, scenario_id: params[cname][:scenario_id])
      va_rule = @delegator.va_rule
      va_rule.trigger_actions(@item, api_current_user)
      @item.save
      # TODO-LongTerm create_scenario_activity should ideally be inside va_rule model and not in the controllers
      @item.create_scenario_activity(va_rule.name)
      head 204
    end

    def latest_note
      @note = @item.conversation.first
      return head(204) if @note.nil?
      @user = ContactDecorator.new(@note.user, {})
    end

    def split_note
      split_the_note
      if @new_ticket.errors.present?
        render_errors(@new_ticket.errors)
      else
        options = { name_mapping: (@name_mapping || get_name_mapping), sideload_options: [] }
        @item = TicketDecorator.new(@new_ticket, options)
        render 'ember/tickets/show'
      end
    end

    def update_properties
      return unless validate_update_property_params
      sanitize_params
      assign_ticket_status
      @item.assign_attributes(validatable_delegator_attributes)
      return unless validate_delegator(@item, ticket_fields: @ticket_fields)
      @item.update_ticket_attributes(params[cname]) ? (head 204) : render_errors(@item.errors)
    end

    private

      def validate_update_property_params
        @ticket_fields = Account.current.ticket_fields_from_cache
        @name_mapping = TicketsValidationHelper.name_mapping(@ticket_fields)
        params_hash = params[cname].merge(statuses: Helpdesk::TicketStatus.status_objects_from_cache(current_account), ticket_fields: @ticket_fields)
        @validation_klass = 'TicketUpdatePropertyValidation'
        validate_body_params(@item, params_hash)
      end

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
        prepare_array_fields(ApiTicketConstants::ARRAY_FIELDS - ['tags']) # Tags not included as it requires more manipulation.

        # Set manual due by to override sla worker triggerd updates.
        params[cname][:manual_dueby] = true if params[cname][:due_by] || params[cname][:fr_due_by]

        params[cname][:attachments] = params[cname][:attachments].map { |att| { resource: att } } if params[cname][:attachments]

        process_custom_fields
        prepare_tags # Sanitizing is required to avoid duplicate records, we are sanitizing here instead of validating in model to avoid extra query.
        process_requester_params
        modify_and_remove_params
        process_saved_params
      end

      def modify_and_remove_params
        # Assign cc_emails serialized hash & collect it in instance variables as it can't be built properly from params
        cc_emails =  params[cname][:cc_emails]

        # Using .dup as otherwise its stored in reference format(&id0001 & *id001).
        @cc_emails = { cc_emails: cc_emails.dup, fwd_emails: [], reply_cc: cc_emails.dup, tkt_cc: cc_emails.dup } unless cc_emails.nil?

        params[cname][:ticket_body_attributes] = { description_html: params[cname][:description] } if params[cname][:description]

        params_to_be_deleted = ApiTicketConstants::PARAMS_TO_REMOVE.dup
        [:due_by, :fr_due_by].each { |key| params_to_be_deleted << key if params[cname][key].nil? }
        ParamsHelper.clean_params(params_to_be_deleted, params[cname])
        ParamsHelper.assign_and_clean_params(ApiTicketConstants::PARAMS_MAPPINGS, params[cname])
        ParamsHelper.save_and_remove_params(self, ApiTicketConstants::PARAMS_TO_SAVE_AND_REMOVE, params[cname])
      end

      def process_saved_params
        # following fields must be handled separately, should not be passed to build_object method
        @attachment_ids = @attachment_ids.map(&:to_i) if @attachment_ids
      end

      def process_custom_fields
        if params[cname][:custom_fields]
          checkbox_names = TicketsValidationHelper.custom_checkbox_names(@ticket_fields)
          ParamsHelper.assign_checkbox_value(params[cname][:custom_fields], checkbox_names)
        end
      end

      def process_requester_params
        # During update set requester_id to nil if it is not a part of params and if any of the contact detail is given in the params
        if update? && !params[cname].key?(:requester_id) && (params[cname].keys & %w(email phone twitter_id facebook_id)).present?
          params[cname][:requester_id] = nil
        end
      end

      def assign_protected
        @item.build_schema_less_ticket unless @item.schema_less_ticket
        @item.account = current_account
        @item.cc_email = @cc_emails unless @cc_emails.nil?
        build_normal_attachments(@item, params[cname][:attachments])
        build_shared_attachments(@item, shared_attachments)
        build_cloud_files(@item, @cloud_files)
        if create? # assign attachments so that it will not be queried again in model callbacks
          @item.attachments = @item.attachments
          @item.ticket_old_body = @item.ticket_old_body # This will prevent ticket_old_body query during save
          @item.inline_attachments = @item.inline_attachments
          @item.schema_less_ticket.product ||= current_portal.product unless params[cname].key?(:product_id)
        end
        assign_ticket_status
      end

      def shared_attachments
        @shared_attachments ||= begin
          current_account.attachments.where('id IN (?) AND attachable_type IN (?)', @attachment_ids, ['Account', 'Admin::CannedResponses::Response'])
        end
      end

      def save_ticket_and_respond
        if create_ticket
          @ticket = @item # Dirty hack. Should revisit.
          render_201_with_location(location_url: 'ticket_url', item_id: @item.display_id)
          notify_cc_people @cc_emails[:cc_emails] unless @cc_emails[:cc_emails].blank? || compose_email?
        else
          render_errors(@item.errors)
        end
      end

      def create_ticket
        @item.attachments = @item.attachments + @delegator.draft_attachments if @delegator.draft_attachments
        @item.save_ticket
      end

      def fetch_objects(items = scoper)
        @items = items.find_all_by_param(permissible_ticket_ids(params[cname][:ids]))
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
        args = { 'action' => :update_multiple, 'helpdesk_ticket' => params_hash }
        args['ids'] = items.map(&:display_id)
        args[:tags] = tags.join(',') unless tags.nil?
        ::Tickets::BulkTicketActions.perform_async(args)
      end

      def decorate_objects
        decorator, options = decorator_options

        if sideload_options.include?('requester') && @items.present?
          @requesters = @items.collect(&:requester).uniq.each_with_object({}) do |contact, hash|
            hash[contact.id] = ContactDecorator.new(contact, name_mapping: contact_name_mapping)
          end
        end

        @items.map! { |item| decorator.new(item, options) } if @items
      end

      def contact_name_mapping
        @contact_name_mapping ||= begin
          custom_field = index? ? User.new.custom_field : @requester.custom_field
          custom_field.each_with_object({}) { |(name, value), hash| hash[name] = CustomFieldDecorator.display_name(name) } if custom_field
        end
      end

      def tickets_filter
        current_account.tickets.permissible(api_current_user).filter(params: params, filter: 'Helpdesk::Filters::CustomTicketFilter')
      end

      def validate_filter_params
        @constants_klass = 'TicketFilterConstants'
        @validation_klass = 'TicketFilterValidation'
        validate_query_params
        @ticket_filter = @validator
      end

      def sanitize_filter_params
        if params[:query_hash].present?
          params[:wf_model] = 'Helpdesk::Ticket'
          params[:data_hash] = QueryHash.new(params[:query_hash].values).to_system_format
        else
          params[:filter] ||= DEFAULT_TICKET_FILTER
        end
        params[:filter] = 'monitored_by' if params[:filter] == 'watching'
        params[:wf_order] = params[:order_by]
        params[:wf_order_type] = params[:order]
      end

      def assign_filter_params
        return unless @delegator.ticket_filter
        params_hash = @delegator.ticket_filter.respond_to?(:id) ? @delegator.ticket_filter.attributes['data'] : { 'filter_name' => params[:filter] }
        params.merge!(params_hash)
      end

      def order_clause
        nil
      end

      def conditional_preload_options
        INDEX_PRELOAD_OPTIONS
      end

      def constants_class
        :ApiTicketConstants.to_s.freeze
      end

      def load_note
        @note = @item.notes.find_by_id(params[:note_id])
        log_and_render_404 unless @note
      end

      def validate_url_params
        params.permit(*ApiTicketConstants::SHOW_FIELDS, *ApiConstants::DEFAULT_PARAMS)
        @include_validation = TicketIncludeValidation.new(params)
        render_errors @include_validation.errors, @include_validation.error_options unless @include_validation.valid?
      end

      wrap_parameters(*wrap_params)
  end
end
