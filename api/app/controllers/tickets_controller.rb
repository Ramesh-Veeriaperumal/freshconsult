class TicketsController < ApiApplicationController
  include Helpdesk::TicketActions
  include Helpdesk::TagMethods
  include CloudFilesHelper
  include TicketConcern
  include SearchHelper
  include AttachmentConcern
  include Search::Filters::QueryHelper
  include Helpdesk::SpamAccountConstants
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Helpdesk::TicketFilterMethods
  include Support::ArchiveTicketsHelper
  include HelperConcern
  include Redis::TicketsRedis
  include AssociateTicketsHelper

  decorate_views(decorate_objects: [:index, :search])
  DEFAULT_TICKET_FILTER = :all_tickets.to_s.freeze
  DESCRIPTION = :description.to_s.freeze

  before_filter :ticket_permission?, only: [:destroy]
  before_filter :check_search_feature, :validate_search_params, only: [:search]
  before_filter :validate_associated_tickets, only: [:create]

  def create
    assign_protected
    return render_request_error(:recipient_limit_exceeded, 429) if recipients_limit_exceeded?
    ticket_delegator = ticket_delegator_class.new(@item, ticket_fields: @ticket_fields,
      custom_fields: params[cname][:custom_field], tags: cname_params[:tags],
      company_id: params[cname][:company_id], parent_attachment_params: parent_attachment_params,
      inline_attachment_ids: @inline_attachment_ids)
    if !ticket_delegator.valid?(:create)
      render_custom_errors(ticket_delegator, true)
    elsif @item.save_ticket
      @ticket = @item # Dirty hack. Should revisit.
      render_201_with_location(item_id: @item.display_id)
      notify_cc_people @cc_emails[:cc_emails] unless @cc_emails[:cc_emails].blank? || compose_email?
    else
      render_errors(@item.errors)
    end
  end

  def update
    assign_protected
    # Assign attributes required as the ticket delegator needs it.
    custom_fields = params[cname][:custom_field] # Assigning it here as it would be deleted in the next statement while assigning.
    @item.assign_attributes(validatable_delegator_attributes)
    @item.assign_description_html(params[cname][:ticket_body_attributes]) if params[cname][:ticket_body_attributes]
    delegator_hash = { ticket_fields: @ticket_fields, custom_fields: custom_fields,
                       company_id: params[cname][:company_id], tags: cname_params[:tags] }
    delegator_hash[:tracker_ticket_id] = cname_params[:tracker_ticket_id] if link_or_unlink?
    ticket_delegator = ticket_delegator_class.new(@item, delegator_hash)
    if !ticket_delegator.valid?(:update)
      render_custom_errors(ticket_delegator, true)
    else
      modify_ticket_associations if link_or_unlink?
      render_errors(@item.errors) unless @item.update_ticket_attributes(params[cname])
    end
  end

  def search
    lookup_and_change_params
    @items = search_query
    add_total_entries(@items.total)
    add_link_header(page: @items.next_page) if @items.next_page.present?
  end

  def destroy
    @item.deleted = true
    store_dirty_tags(@item) # Storing tags whenever ticket is deleted. So that tag count is in sync with DB.
    @item.save
    head 204
  end

  def restore
    @item.deleted = false
    restore_dirty_tags(@item)
    @item.save
    head 204
  end

  def show
    sideload_associations if @include_validation.include_array.present?
    super
  end

  def self.wrap_params
    ApiTicketConstants::WRAP_PARAMS
  end

  protected

    def requires_feature(feature)
      return if !compose_email?
      if Account.current.compose_email_enabled?
        return render_request_error(:outbound_limit_exceeded, 429) if trial_outbound_limit_exceeded?
        return render_request_error(:access_denied, 403) unless Account.current.verified?
      else
        render_request_error(:require_feature, 403, feature: feature.to_s.titleize)
      end
    end

  private
    # delegator class to be used when calling create or update
    def ticket_delegator_class
      'TicketDelegator'.constantize
    end

    # Same as http://apidock.com/rails/Hash/extract! without the shortcomings in http://apidock.com/rails/Hash/extract%21#1530-Non-existent-key-semantics-changed-
    # extract the keys from the hash & delete the same in the original hash to avoid repeat assignments
    def validatable_delegator_attributes
      params[cname].select do |key, value|
        if ApiTicketConstants::VALIDATABLE_DELEGATOR_ATTRIBUTES.include?(key)
          params[cname].delete(key)
          true
        end
      end
    end

    def feature_name
      FeatureConstants::TICKETS
    end

    def sideload_associations
      @include_validation.include_array.each { |association| increment_api_credit_by(1) }
    end

    def decorator_options(options = {})
      options[:name_mapping] = @name_mapping || get_name_mapping
      options[:sideload_options] = sideload_options.to_a if index? || show?
      super(options)
    end

    def get_name_mapping
      # will be called only for index and show.
      # We want to avoid memcache call to get custom_field keys and hence following below approach.
      mapping = Account.current.ticket_field_def.ff_alias_column_mapping
      mapping.each_with_object({}) { |(ff_alias, column), hash| hash[ff_alias] = TicketDecorator.display_name(ff_alias) } if @item || @items.present?
    end

    def sideload_options
      index? ? @ticket_filter.try(:include_array) : @include_validation.try(:include_array)
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields(field_mappings, item)
    end

    def load_objects
      if current_account.count_es_api_enabled?
        tickets_from_es
      else
        Rails.logger.info ":::Loading objects started:::"
        super tickets_filter.preload(conditional_preload_options)
        Rails.logger.info ":::Loading objects done:::"
      end
    end

    def tickets_from_es
      es_options = {
        page:         params[:page] || 1,
        order_entity: params[:order_by] || ApiTicketConstants::DEFAULT_ORDER_BY,
        order_sort:   params[:order_type] || ApiTicketConstants::DEFAULT_ORDER_TYPE
      }
      @items = Search::Tickets::Docs.new(d_query_hash).records('Helpdesk::Ticket', es_options)
    end

    def d_query_hash
      @action_hash = []
      TicketConstants::LIST_FILTER_MAPPING.each do |key, val| # constructs hash for custom_filters
        @action_hash.push('condition' => val, 'operator' => 'is_in', 'value' => params[key].to_s) if params[key].present?
      end
      predefined_filters_hash # constructs hash for predefined_filters
      @action_hash
    end

    def predefined_filters_hash
      if sanitize_filter_params # sanitize filter name
        assign_filter_params # assign filter_name param
        custom_tkt_filter = Helpdesk::Filters::CustomTicketFilter.new
        @action_hash.push(custom_tkt_filter.default_filter(params[:filter_name])).flatten!
      end
    end

    def sanitize_filter_params
      if TicketFilterConstants::RENAME_FILTER_NAMES.keys.include?(params[:filter])
        params[:filter] = TicketFilterConstants::RENAME_FILTER_NAMES[params[:filter]]
      elsif @action_hash.empty?
        params[:filter] ||= DEFAULT_TICKET_FILTER
      end
      params[:filter]
    end

    def assign_filter_params
      params_hash = { 'filter_name' => params[:filter] }
      params.merge!(params_hash)
    end

    def conditional_preload_options
      preload_options = [:schema_less_ticket, :flexifield, :tags]
      @ticket_filter.include_array.each do |assoc|
        preload_options << (ApiTicketConstants::INCLUDE_PRELOAD_MAPPING[assoc.to_sym] || assoc)
        increment_api_credit_by(2) unless (assoc.to_s == DESCRIPTION && !current_account.description_by_request_enabled?)
      end
      Rails.logger.info ":::preloads: #{preload_options.inspect}"
      preload_options
    end

    def after_load_object
      verify_ticket_state_and_permission
    end

    def paginate_options(is_array = false)
      options = super(is_array)
      options[:order] = order_clause
      options
    end

    def order_clause
      order_by = params[:order_by] || ApiTicketConstants::DEFAULT_ORDER_BY
      order_type = params[:order_type] || ApiTicketConstants::DEFAULT_ORDER_TYPE
      "helpdesk_tickets.#{order_by} #{order_type} "
    end

    def tickets_filter
      filter = Helpdesk::Ticket.filter_conditions(@ticket_filter, api_current_user)
      filter_conditions = @ticket_filter.conditions.map!(&:to_sym)
      tickets = scoper.where(default_conditions(filter_conditions)).permissible(api_current_user)
      filter_conditions.each do |key|
        clause = filter[key] || {}
        tickets = tickets.where(clause[:conditions]).joins(clause[:joins])
        # method chaining is done here as, clause[:conditions] could be an array or a hash
      end
      tickets
    end

    def default_conditions(filter_conditions)
      # For spam filter, spam: true condition from model method #filter_conditions would override spam: false set here. And deleted: false would be set.
      # For deleted filter, spam is a don't care and deleted: true from model method #filter_conditions would override deleted: false set here.
      # For all others spam: false and deleted: false would be set.
      conditions = { deleted: false }
      conditions[:spam] = false unless filter_conditions.include?(:deleted)
      conditions
    end

    def validate_filter_params
      include_description unless description_included? || current_account.description_by_request_enabled?
      params.permit(*ApiTicketConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      @ticket_filter = TicketFilterValidation.new(params, nil, string_request_params?)
      render_errors(@ticket_filter.errors, @ticket_filter.error_options) unless @ticket_filter.valid?
    end

    def validate_search_params
      name_mapping_txt_fields = searchable_text_ff_fields
      custom_fields = name_mapping_txt_fields.empty? ? [nil] : name_mapping_txt_fields.keys
      params.permit(*ApiTicketConstants::SEARCH_ALLOWED_DEFAULT_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS, *custom_fields)
      @ticket_filter = TicketFilterValidation.new(params.merge(cf: custom_fields))
      render_errors(@ticket_filter.errors, @ticket_filter.error_options) unless @ticket_filter.valid?
    end

    def description_included?
      !params[:include].nil? && params[:include].include?(DESCRIPTION)
    end

    def include_description
      params[:include] = params[:include].nil? ? DESCRIPTION : "#{params[:include]},#{DESCRIPTION}"
    end

    def scoper
      current_account.tickets
    end

    def remove_ignore_params
      params[cname].except!(*ApiTicketConstants::IGNORE_PARAMS)
    end

    def validate_url_params
      params.permit(*ApiTicketConstants::SHOW_FIELDS, *ApiConstants::DEFAULT_PARAMS)
      @include_validation = TicketIncludeValidation.new(params)
      render_errors @include_validation.errors, @include_validation.error_options unless @include_validation.valid?
    end

    def sanitize_params
      prepare_array_fields(ApiTicketConstants::ARRAY_FIELDS - ['tags']) # Tags not included as it requires more manipulation.

      # Assign cc_emails serialized hash & collect it in instance variables as it can't be built properly from params
      cc_emails =  params[cname][:cc_emails]

      # Using .dup as otherwise its stored in reference format(&id0001 & *id001).
      @cc_emails = { cc_emails: cc_emails.dup, fwd_emails: [], reply_cc: cc_emails.dup, tkt_cc: cc_emails.dup } unless cc_emails.nil?

      # Set manual due by to override sla worker triggerd updates.
      params[cname][:manual_dueby] = true if params[cname][:due_by] || params[cname][:fr_due_by]

      if params[cname][:custom_fields]
        checkbox_names = TicketsValidationHelper.custom_checkbox_names(@ticket_fields)
        ParamsHelper.assign_checkbox_value(params[cname][:custom_fields], checkbox_names)
      end
      sanitize_cloud_files(params[cname][:cloud_files]) if private_api?

      params_to_be_deleted = [:cc_emails]
      [:due_by, :fr_due_by].each { |key| params_to_be_deleted << key if params[cname][key].nil? }
      ParamsHelper.clean_params(params_to_be_deleted, params[cname])

      # Assign original fields from api params and clean api params.
      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field, fr_due_by: :frDueBy,
                                             type: :ticket_type, parent_id: :assoc_parent_tkt_id, tracker_id: :tracker_ticket_id }, params[cname])
      ParamsHelper.save_and_remove_params(self, [:cloud_files, :inline_attachment_ids], params[cname]) if private_api?

      # Sanitizing is required to avoid duplicate records, we are sanitizing here instead of validating in model to avoid extra query.
      prepare_tags

      # build ticket body attributes from description and description_html
      build_ticket_body_attributes
      params[cname][:attachments] = params[cname][:attachments].map { |att| { resource: att } } if params[cname][:attachments]

      # During update set requester_id to nil if it is not a part of params and if any of the contact detail is given in the params
      if update? && !params[cname].key?(:requester_id) && (params[cname].keys &
          ApiTicketConstants::VERIFY_REQUESTER_ON_PROPERTY_VALUE_CHANGES).present?
        params[cname][:requester_id] = nil
      end

      @status = params[cname].delete(:status) if params[cname].key?(:status) # We are removing status from params as status= model method makes memcache calls.
    end

    def prepare_tags
      tags = sanitize_tags(params[cname][:tags]) if create? || params[cname].key?(:tags)
      params[cname][:tags] = construct_tags(tags) if tags
    end

    def constants_class
      ApiTicketConstants.to_s.freeze
    end

    def validation_class
      service_task = Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE
      if params[cname][:type] == service_task || (@item && @item.ticket_type == service_task)
        FsmTicketValidation
      else
        TicketValidation
      end
    end

    def validate_params
      # We are obtaining the mapping in order to swap the field names while rendering(both successful and erroneous requests), instead of formatting the fields again.
      @ticket_fields = Account.current.ticket_fields_from_cache
      @name_mapping = TicketsValidationHelper.name_mapping(@ticket_fields) # -> {:text_1 => :text}
      # Should not allow any key value pair inside custom fields hash if no custom fields are available for accnt.
      custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
      field = "#{constants_class}::#{original_action_name.upcase}_FIELDS".constantize | ['custom_fields' => custom_fields]
      params[cname].permit(*field)
      set_default_values
      params_hash = params[cname].merge(statuses: Helpdesk::TicketStatus.status_objects_from_cache(current_account), ticket_fields: @ticket_fields)
      additional_params = get_additional_params
      ticket = validation_class.new(params_hash, @item, string_request_params?, additional_params)
      render_custom_errors(ticket, true) unless ticket.valid?(original_action_name.to_sym)
    end

    def get_additional_params
      # placeholder function to pass additional params into ticket validation
    end

    def set_default_values
      if compose_email?
        params[cname][:status] = ApiTicketConstants::CLOSED unless params[cname].key?(:status)
        params[cname][:source] = TicketConstants::SOURCE_KEYS_BY_TOKEN[:outbound_email]
      end
      ParamsHelper.modify_custom_fields(params[cname][:custom_fields], @name_mapping.invert) # Using map instead of invert does not show any perf improvement.
    end

    def assign_protected
      @item.build_schema_less_ticket unless @item.schema_less_ticket
      @item.account = current_account
      @item.cc_email = @cc_emails unless @cc_emails.nil?
      @item.inline_attachment_ids = @inline_attachment_ids
      assign_association_type
      build_attachments
      if create? # assign attachments so that it will not be queried again in model callbacks
        @item.attachments = @item.attachments
        @item.cloud_files = @item.cloud_files if private_api?
        @item.ticket_old_body = @item.ticket_old_body # This will prevent ticket_old_body query during save
        @item.inline_attachments = @item.inline_attachments
        @item.schema_less_ticket.product ||= current_portal.product unless params[cname].key?(:product_id)
      end
      assign_ticket_status
    end

    def build_attachments
      build_normal_attachments(@item, params[cname][:attachments]) if params[cname][:attachments]
      build_cloud_files(@item, @cloud_files) if private_api? && @cloud_files
    end

    def check_search_feature
      log_and_render_404 unless current_account.launched?(:api_search_beta)
    end

    def build_ticket_body_attributes
      if params[cname][:description]
        ticket_body_hash = { ticket_body_attributes: { description_html: params[cname][:description] } }
        params[cname].merge!(ticket_body_hash).tap do |t|
          t.delete(:description) if t[:description]
        end
      end
    end

    def load_object
      @item = scoper.find_by_display_id(params[:id])
      log_and_render_404 unless @item
    end

    def parent_attachment_params
      {
        parent_ticket:       parent_ticket,
        parent_attachments:  parent_attachments
      }
    end

    def assign_ticket_status
      @item[:status] = @status if defined?(@status)
      @item[:status] ||= OPEN
    end

    def restore?
      @restore ||= current_action?('restore')
    end

    def compose_email?
      @compose_email ||= params.key?('_action') ? params['_action'] == 'compose_email' : action_name.to_s == 'compose_email'
    end

    def original_action_name
      @original_action_name ||= compose_email? ? 'compose_email' : action_name
    end

    def error_options_mappings
      field_mappings
    end

    def valid_content_type?
      return true if super
      allowed_content_types = ApiTicketConstants::ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym] || [:json]
      allowed_content_types.include?(request.content_mime_type.ref)
    end

    def search_query
      es_options = {
        per_page: params[:per_page] || 30,
        page: params[:page] || 1,
        order_entity: params[:order_by] || 'created_at',
        order_sort: params[:order_type] || 'desc'
      }
      neg_conditions = [Helpdesk::Filters::CustomTicketFilter.deleted_condition(true), Helpdesk::Filters::CustomTicketFilter.spam_condition(true)]
      conditions = params[:search_conditions].collect { |s_c| { 'condition' => s_c.first, 'operator' => 'is_in', 'value' => s_c.last.join(',') } }
      Search::Tickets::Docs.new(conditions, neg_conditions).records('Helpdesk::Ticket', es_options)
    end

    def trial_outbound_limit_exceeded?
      outbound_per_day_key = OUTBOUND_EMAIL_COUNT_PER_DAY % {:account_id => current_account.id }
      total_outbound_per_day = get_others_redis_key(outbound_per_day_key).to_i
      if ((current_account.id > get_spam_account_id_threshold) && (current_account.subscription.trial?) && (!ismember?(SPAM_WHITELISTED_ACCOUNTS, current_account.id)))
        return total_outbound_per_day >= 5
      elsif current_account.subscription.free?
        if current_account.created_at >= (Time.zone.now - 30.days)
          return total_outbound_per_day >= get_free_account_30_days_threshold
        else
          return total_outbound_per_day >= get_free_account_outbound_threshold
        end
      end
      return false
    end

    def recipients_limit_exceeded?
      if ((current_account.id > get_spam_account_id_threshold) && (current_account.subscription.trial?) && (!ismember?(SPAM_WHITELISTED_ACCOUNTS, current_account.id)) && (Freemail.free?(current_account.admin_email)))
        if (@item.source == Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:outbound_email] || @item.source == Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:phone])
          return max_cc_threshold_crossed?
        end
      end
      return false
    end

    def max_cc_threshold_crossed?
      # In all cases requester or email will be single. So checking cc_emails count makes sense
      cc_emails = @cc_emails[:cc_emails]
      return (cc_emails.count >= get_trial_account_max_to_cc_threshold)
    end

    def field_mappings
      (custom_field_error_mappings || {}).merge(ApiTicketConstants::FIELD_MAPPINGS)
    end


    # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
    wrap_parameters(*wrap_params)
end
