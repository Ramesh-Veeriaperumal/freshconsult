module Ember
  class TicketsController < ::TicketsController
    include TicketConcern
    include HelperConcern
    include SplitNoteHelper
    include AttachmentConcern
    include Helpdesk::ToggleEmailNotification
    decorate_views(decorate_object: [:update_properties], decorate_objects: [:index, :search])

    INDEX_PRELOAD_OPTIONS = [:tags, :ticket_old_body, :schema_less_ticket, :flexifield, { requester: [:avatar, :flexifield, :default_user_company] }].freeze
    DEFAULT_TICKET_FILTER = :all_tickets.to_s.freeze
    SINGULAR_RESPONSE_FOR = %w(show create update split_note update_properties).freeze

    before_filter :ticket_permission?, only: [:latest_note, :split_note]
    before_filter :load_note, only: [:split_note]
    before_filter :disable_notification, if: :notification_not_required?
    after_filter  :enable_notification, if: :notification_not_required?

    def index
      sanitize_filter_params
      @delegator_klass = 'TicketFilterDelegator'
      return unless validate_delegator(nil, params)
      assign_filter_params
      super
      response.api_meta = { count: @items_count } if count_included?
    end

    def create
      assign_protected
      delegator_hash = { ticket_fields: @ticket_fields, custom_fields: cname_params[:custom_field],
                         attachment_ids: @attachment_ids, shared_attachments: shared_attachments }
      return unless validate_delegator(@item, delegator_hash)
      save_ticket_and_respond
    end

    def update
      assign_protected
      delegator_hash = { ticket_fields: @ticket_fields, custom_fields: cname_params[:custom_field],
                         attachment_ids: @attachment_ids, shared_attachments: shared_attachments }
      assign_attributes_for_update
      return unless validate_delegator(@item, delegator_hash)
      @item.attachments = @item.attachments + @delegator.draft_attachments if @delegator.draft_attachments
      if @item.update_ticket_attributes(cname_params)
        render 'ember/tickets/show'
      else
        render_errors(@item.errors)
      end
    end

    def execute_scenario
      return unless validate_body_params
      @delegator_klass = 'ScenarioDelegator'
      return unless validate_delegator(@item, scenario_id: cname_params[:scenario_id])
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
      if @item.update_ticket_attributes(cname_params)
        render 'ember/tickets/show'
      else
        render_errors(@item.errors)
      end
    end

    private

      def validate_update_property_params
        @ticket_fields = Account.current.ticket_fields_from_cache
        @name_mapping = TicketsValidationHelper.name_mapping(@ticket_fields)
        params_hash = cname_params.merge(statuses: Helpdesk::TicketStatus.status_objects_from_cache(current_account), ticket_fields: @ticket_fields)
        @validation_klass = 'TicketUpdatePropertyValidation'
        validate_body_params(@item, params_hash)
      end

      def sanitize_params
        sanitize_ticket_params
      end

      def assign_protected
        @item.build_schema_less_ticket unless @item.schema_less_ticket
        @item.account = current_account
        @item.cc_email = @cc_emails unless @cc_emails.nil?
        assign_attachments
        assign_attributes_for_create if create?
        assign_ticket_status
      end

      def assign_attachments
        build_normal_attachments(@item, cname_params[:attachments])
        build_shared_attachments(@item, shared_attachments)
        build_cloud_files(@item, @cloud_files)
      end

      def assign_attributes_for_create
        # assign attribute so that it will not be queried again in model callbacks
        @item.attachments = @item.attachments
        @item.ticket_old_body = @item.ticket_old_body # This will prevent ticket_old_body query during save
        @item.inline_attachments = @item.inline_attachments
        @item.schema_less_ticket.product ||= current_portal.product unless cname_params.key?(:product_id)
      end

      def assign_attributes_for_update
        @item.assign_attributes(validatable_delegator_attributes)
        @item.assign_description_html(cname_params[:ticket_body_attributes]) if cname_params[:ticket_body_attributes]
      end

      def load_objects
        items = tickets_filter.preload(conditional_preload_options)
        @items_count = items.count if count_included?
        @items = paginate_items(items)
      end

      def count_included?
        @ticket_filter.include_array && @ticket_filter.include_array.include?('count')
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

      def decorate_objects
        return if @errors || @error
        decorator, options = decorator_options
        @items.map! { |item| decorator.new(item, options) } if @items
      end

      def decorator_options
        options = {}
        if (sideload_options || []).include?('requester')
          options = { contact_name_mapping: contact_name_mapping, company_name_mapping: company_name_mapping}
        end
        super(options)
      end

      def contact_name_mapping
        @contact_name_mapping ||= begin
          custom_field = User.new.custom_field
          custom_field.each_with_object({}) { |(name, value), hash| hash[name] = CustomFieldDecorator.display_name(name) } if custom_field
        end
      end

      def company_name_mapping
        @company_name_mapping ||= begin
          custom_field = Company.new.custom_field
          custom_field.each_with_object({}) { |(name, value), hash| hash[name] = CustomFieldDecorator.display_name(name) } if custom_field
        end
      end

      def tickets_filter
        filtered_tickets = current_account.tickets.permissible(api_current_user).filter(params: params.except(:ids), filter: 'Helpdesk::Filters::CustomTicketFilter')
        params[:ids].present? ? filtered_tickets.where(display_id: params[:ids]) : filtered_tickets
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
        map_filter_params
      end

      def map_filter_params
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

      def notification_not_required?
        cname_params.present? && cname_params[:skip_close_notification].try(:to_s) == 'true'
      end

      def validate_url_params
        params.permit(*ApiTicketConstants::SHOW_FIELDS, *ApiConstants::DEFAULT_PARAMS)
        @include_validation = TicketIncludeValidation.new(params)
        render_errors @include_validation.errors, @include_validation.error_options unless @include_validation.valid?
      end

      wrap_parameters(*wrap_params)
  end
end
