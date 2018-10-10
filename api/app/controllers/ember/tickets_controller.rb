module Ember
  class TicketsController < ::TicketsController
    include TicketConcern
    include HelperConcern
    include SplitNoteHelper
    include AttachmentConcern
    include Helpdesk::ToggleEmailNotification
    include Redis::RedisKeys
    include Redis::OthersRedis
    include Helpdesk::Activities::ActivityMethods
    include ExportHelper
    decorate_views(decorate_object: [:update_properties, :execute_scenario], decorate_objects: [:index, :search])

    SLAVE_ACTIONS = %w(latest_note).freeze

    INDEX_PRELOAD_OPTIONS = [:ticket_states, :tags, :schema_less_ticket, :ticket_status, { flexifield: [:denormalized_flexifield]}, { requester: [:avatar, :flexifield, :companies, :user_emails, :tags] }, :custom_survey_results].freeze
    DEFAULT_TICKET_FILTER = :all_tickets.to_s.freeze
    SINGULAR_RESPONSE_FOR = %w(show create update split_note update_properties execute_scenario).freeze

    before_filter :ticket_permission?, only: [:latest_note, :split_note]
    before_filter :load_note, only: [:split_note]
    before_filter :disable_notification, only: [:update, :update_properties], if: :notification_not_required?
    after_filter  :enable_notification, only: [:update, :update_properties], if: :notification_not_required?
    before_filter :export_limit_reached?, only: [:export_csv]
    around_filter :run_on_db, only: :index
    around_filter :use_time_zone, only: [:index, :export_csv]

    def index
      sanitize_filter_params
      @delegator_klass = 'TicketFilterDelegator'
      return unless validate_delegator(nil, params)
      assign_filter_params
      super
      response.api_meta = { count: @items_count } if params[:only] == 'count'
      (response.api_meta ||= {}).merge!(background_info)
    end

    def create
      assign_protected
      return render_request_error(:recipient_limit_exceeded, 429) if recipients_limit_exceeded?
      delegator_hash = { ticket_fields: @ticket_fields, custom_fields: cname_params[:custom_field],
                         attachment_ids: @attachment_ids, shared_attachments: shared_attachments,
                         parent_child_params: parent_child_params, parent_attachment_params: parent_attachment_params,
                         tags: cname_params[:tags], company_id: cname_params[:company_id], inline_attachment_ids: @inline_attachment_ids,
                         topic_id: @topic_id }
      return unless validate_delegator(@item, delegator_hash)
      save_ticket_and_respond
    end

    def update
      assign_protected
      delegator_hash = { ticket_fields: @ticket_fields, custom_fields: cname_params[:custom_field],
                         attachment_ids: @attachment_ids, shared_attachments: shared_attachments,
                         company_id: cname_params[:company_id] }
      delegator_hash[:tracker_ticket_id] = cname_params[:tracker_ticket_id] if link_or_unlink?
      assign_attributes_for_update
      return unless validate_delegator(@item, delegator_hash)
      modify_ticket_associations if link_or_unlink?
      @item.attachments = @item.attachments + @delegator.draft_attachments if @delegator.draft_attachments
      if @item.update_ticket_attributes(cname_params)
        render 'ember/tickets/show'
      else
        render_errors(@item.errors)
      end
    end

    def parse_template
      ticket = @item.to_liquid
      @validation_klass = 'TicketValidation'
      return unless validate_body_params(@item, params)

      begin
        @response_text = Liquid::Template.parse(params[:template_text]).render({ ticket: ticket }.stringify_keys)
        render 'ember/tickets/parse_liquid'
      rescue Exception => e
        @item.errors[:template_text] << :"is invalid"
        render_custom_errors(@item)
      end
    end

    def create_child_with_template
      @validation_klass = 'CreateChildWithTemplateValidation'
      return unless validate_body_params
      @delegator_klass = 'CreateChildWithTemplateDelegator'
      return unless validate_delegator(@item, parent_child_params: parent_child_params)
      create_child_template_tickets
      head 204
    end

    def execute_scenario
      return unless validate_body_params
      fetch_ticket_fields_mapping
      return unless validate_scenario_execution
      va_rule = @delegator.va_rule
      if va_rule.trigger_actions(@item, api_current_user)
        @item.save
        @item.create_scenario_activity(va_rule.name)
        scenario_activities = va_rule.actions.collect { |a| a.logger_actions}.compact
        scenario_activities.each do |hash|
          if @item.custom_field && CustomFieldDecorator.custom_field?(hash[:name])
            custom_string = "custom_fields."
            hash[:name] = custom_string << TicketDecorator.display_name(hash[:name])
          elsif hash[:comment]
            hash.delete(:comment)
          end
        end
        response.api_meta = { activities: scenario_activities}
        Va::RuleActivityLogger.clear_activities
        render 'ember/tickets/show'
      else
        render_errors(@item.errors)
      end
    end

    def latest_note
      @note = @item.conversation.first
      if @note.nil?
        response.api_root_key = :ticket
      else
        @user = ContactDecorator.new(@note.user, {})
        response.api_root_key = :conversation
      end
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
      delegator_hash = { ticket_fields: @ticket_fields, attachment_ids: @attachment_ids, tags: cname_params[:tags], inline_attachment_ids: @inline_attachment_ids }
      return unless validate_delegator(@item, delegator_hash)
      @item.attachments = @item.attachments + @delegator.draft_attachments if @delegator.draft_attachments
      @item.inline_attachment_ids = @inline_attachment_ids
      build_cloud_files(@item, @cloud_files)
      if @item.update_ticket_attributes(cname_params)
        render 'ember/tickets/show'
      else
        render_errors(@item.errors)
      end
    end

    def export_limit_reached?
      if DataExport.ticket_export_limit_reached?(User.current)
        export_limit = DataExport.ticket_export_limit
        return render_request_error_with_info(:export_ticket_limit_reached, 429, {max_limit: export_limit}, {:max_simultaneous_export => export_limit }) 
      end
    end

    def export_csv
      @validation_klass = 'TicketExportValidation'
      return unless validate_body_params(@item, validate_export_params(cname_params))
      sanitize_export_params
      Export::Ticket.enqueue(build_export_hash)
      head 204
    end

    private

      def archive_scoper
        current_account.archive_tickets
      end

      def validate_scenario_execution
        @delegator_klass = 'ScenarioDelegator'
        delegator_hash = {
          scenario_id: cname_params[:scenario_id],
          user: api_current_user,
          ticket_fields: @ticket_fields,
          statuses: @statuses
        }
        validate_delegator(@item, delegator_hash)
      end

      def validate_update_property_params
        fetch_ticket_fields_mapping
        params_hash = cname_params.merge(statuses: @statuses, ticket_fields: @ticket_fields)
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
        assign_association_type
        assign_attachments
        assign_attributes_for_create if create?
        assign_ticket_status
      end

      def assign_attachments
        load_normal_attachments
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

        # Default source is set to phone. Instead of portal as set in the model.
        @item.source = TicketConstants::SOURCE_KEYS_BY_TOKEN[:phone] if @item.source === 0
      end

      def assign_attributes_for_update
        @item.assign_attributes(validatable_delegator_attributes)
        @item.assign_description_html(cname_params[:ticket_body_attributes]) if cname_params[:ticket_body_attributes]
      end

      def load_objects
        items = tickets_filter.preload(conditional_preload_options)
        if params[:only] == 'count'
          @items_count = optimized_count(items)
          @items = []
          return
        end
        @items = paginate_items(items)
      end

      def load_object
        @item = scoper.find_by_display_id(params[:id])
        unless @item
          # If the ticket is archive redirect with 301.
          archive_ticket = if current_account.features_included?(:archive_tickets)
            archive_scoper.find_by_display_id(params[:id])
          else
            nil
          end
          (archive_ticket.present?) ? log_and_render_301_archive : log_and_render_404 
        end
      end

      def log_and_render_301_archive
        Rails.logger.debug "The ticket is archived. Id: #{params[:id]}, method: #{params[:action]}, controller: #{params[:controller]}"
        redirect_to archive_ticket_link, status: 301
      end

      def archive_ticket_link
        redirect_link = "/api/_/tickets/archived/#{params[:id]}"
        (archive_params.present?) ? "#{redirect_link}?#{archive_params}": redirect_link
      end

      def archive_params
        include_params = params.select{|k,v| ApiTicketConstants::PERMITTED_ARCHIVE_FIELDS.include?(k)}
        include_params.to_query
      end

      def load_normal_attachments
        attachments_array = cname_params[:attachments] || []
        (parent_attachments || []).each do |attach|
          attachments_array.push(resource: attach.to_io)
        end
        (parent_template_attachments || []).each do |attach|
          attachments_array.push(resource: attach.to_io)
        end
        cname_params[:attachments] = attachments_array
      end

      def parent_template_attachments
        @template_attachments ||= if @attachment_ids.present? && parent_template.present?
          parent_template.attachments.select { |x| @attachment_ids.include?(x.id) }
        else
          []
        end
      end

      def parent_template
        @parent_template ||= current_account.prime_templates.find_by_id(@parent_template_id) if @parent_template_id.present?
      end

      def count_included?
        @ticket_filter.include_array && @ticket_filter.include_array.include?('count')
      end

      def shared_attachments
        shared_attachment_ids = @attachment_ids ? @attachment_ids - parent_template_attachments.map(&:id) : @attachments_ids
        @shared_attachments ||= begin
          current_account.attachments.where('id IN (?) AND attachable_type IN (?)', shared_attachment_ids, AttachmentConstants::CLONEABLE_ATTACHMENT_TYPES)
        end
      end

      def save_ticket_and_respond
        if create_ticket
          @ticket = @item # Dirty hack. Should revisit.
          create_child_template_tickets
          render 'ember/tickets/show', status: 201
          notify_cc_people @cc_emails[:cc_emails] unless @cc_emails[:cc_emails].blank? || compose_email?
        else
          render_errors(@item.errors)
        end
      end

      def create_ticket
        @item.attachments = @item.attachments + @delegator.draft_attachments if @delegator.draft_attachments
        @item.inline_attachment_ids = @inline_attachment_ids
        build_topic_ticket if @topic_id
        @item.save_ticket
      end

      def build_topic_ticket
        @item.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:forum]
        @item.build_ticket_topic(topic_id: @topic_id)
      end

      def create_child_template_tickets
        return if parent_child_params[:child_template_ids].blank?
        ::Tickets::BulkChildTktCreation.perform_async(user_id: current_user.id,
                                                      portal_id: current_portal.id,
                                                      assoc_parent_tkt_id: @item.display_id,
                                                      parent_templ_id: parent_child_params[:parent_template_id],
                                                      child_ids: parent_child_params[:child_template_ids])
      end

      def decorate_objects
        decorator, options = decorator_options
        @items.map! { |item| decorator.new(item, options) } if @items
      end

      def decorator_options
        options = {}
        if (sideload_options || []).include?('requester')
          options[:contact_name_mapping] = contact_name_mapping
          options[:company_name_mapping] = company_name_mapping
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
        filtered_tickets = current_account.tickets.permissible(api_current_user).filter(ticket_filter_params)
        filtered_tickets = params[:ids].present? ? filtered_tickets.where(display_id: params[:ids]) : filtered_tickets
        params[:updated_since].present? ? filtered_tickets.where('helpdesk_tickets.updated_at >= ?', Time.parse(params[:updated_since])) : filtered_tickets
      end

      def ticket_filter_params
        # format (json) is checked in CustomTicketFilter for API v2 to filter all tickets without last 30 days created_at limit
        # ids are not accepted by CustomTicketFilter, so ignoring it also.
        {
          params: params.except(:ids, :format).merge(order_params),
          filter: 'Helpdesk::Filters::CustomTicketFilter'
        }
      end

      def order_params
        remap = {}
        remap[:wf_order] = params[:order_by] if params[:order_by]
        remap[:wf_order_type] = params[:order_type] if params[:order_type]
        remap
      end

      def validate_filter_params
        @constants_klass = 'TicketFilterConstants'
        @validation_klass = 'TicketFilterValidation'
        validate_query_params
        @ticket_filter = @validator
      end

      def wf_query_hash
        @wf_query_hash ||= begin
          filter = Helpdesk::Filters::CustomTicketFilter.new
          filter.deserialize_from_params(ticket_filter_params[:params])
          filter.query_hash
        end
      end

      def optimized_count(items)
        if !default_filter? && current_account.count_es_enabled?
          ::Search::Tickets::Docs.new(wf_query_hash).count(Helpdesk::Ticket)
        else
          items.count
        end
      end

      def default_filter?
        !@delegator.ticket_filter.respond_to?(:id)
      end

      def sanitize_filter_params
        if params.key?(:query_hash)
          params[:wf_model] = 'Helpdesk::Ticket'
          params[:data_hash] = QueryHash.new(params[:query_hash].present? ? params[:query_hash].values : []).to_system_format
        else
          params[:filter] ||= DEFAULT_TICKET_FILTER
        end
        renamed_filter  = TicketFilterConstants::RENAME_FILTER_NAMES[params[:filter]]
        params[:filter] = renamed_filter if renamed_filter.present?
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
        params['include'].to_s.include?('company') ? INDEX_PRELOAD_OPTIONS.dup.push(:company) : INDEX_PRELOAD_OPTIONS
      end

      def constants_class
        :ApiTicketConstants.to_s.freeze
      end

      def load_note
        @note = @item.notes.find_by_id(params[:note_id])
        log_and_render_404 unless @note
      end

      def notification_not_required?
        @skip_close_notification ||= cname_params.try(:[], :skip_close_notification)
      end

      def validate_url_params
        params.permit(*ApiTicketConstants::SHOW_FIELDS, *ApiConstants::DEFAULT_PARAMS)
        @include_validation = TicketIncludeValidation.new(params)
        render_errors @include_validation.errors, @include_validation.error_options unless @include_validation.valid?
      end

      def background_info
        return {} unless %w(spam deleted).include?(params[:filter])
        key = params[:filter] == 'spam' ? empty_spam_key : empty_trash_key
        {
          emptying_on_background: get_others_redis_key(key) || false
        }
      end

      def empty_spam_key
        EMPTY_SPAM_TICKETS % { account_id: current_account.id }
      end

      def empty_trash_key
        EMPTY_TRASH_TICKETS % { account_id: current_account.id }
      end

      def sanitize_export_params
        # set_date_filter
        if !(cname_params[:date_filter].to_i == TicketConstants::CREATED_BY_KEYS_BY_TOKEN[:custom_filter])
          cname_params[:start_date] = cname_params[:date_filter].to_i.days.ago.beginning_of_day.to_s(:db)
          cname_params[:end_date] = Time.now.end_of_day.to_s(:db)
        else
          cname_params[:start_date] = Time.zone.parse(cname_params[:start_date]).to_s(:db)
          cname_params[:end_date] = Time.zone.parse(cname_params[:end_date]).end_of_day.to_s(:db)
        end

        # set_default_filter
        cname_params[:filter_name] = 'all_tickets' if cname_params[:filter_name].blank? && cname_params[:filter_key].blank? && cname_params[:data_hash].blank?
        # When there is no data hash sent selecting all_tickets instead of new_and_my_open

        sanitize_custom_fields(cname_params)
      end

      def build_export_hash
        cname_params.merge!(export_fields: cname_params[:ticket_fields],
                            data_hash: QueryHash.new(cname_params[:query_hash]).to_system_format,
                            current_user_id: api_current_user.id,
                            portal_url: portal_url)
      end

      def parent_child_params
        @parent_child_params ||= begin
          {
            parent_template_id:  (params[:parent_template_id] || @parent_template_id),
            child_template_ids:  (params[:child_template_ids] || @child_template_ids)
          }
        end
      end

      def parent_attachment_params
        {
          parent_ticket:       parent_ticket,
          parent_attachments:  parent_attachments,
          parent_template_attachments: parent_template_attachments
        }
      end

      def portal_url
        main_portal? ? current_account.host : current_portal.portal_url
      end
      wrap_parameters(*wrap_params)
  end
end
