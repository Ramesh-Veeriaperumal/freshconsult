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
  include AdvancedTicketScopes

  decorate_views(decorate_objects: [:index])
  DEFAULT_TICKET_FILTER = :all_tickets.to_s.freeze
  DESCRIPTION = :description.to_s.freeze

  before_filter :ticket_permission?, only: [:destroy, :vault_token]
  before_filter :secure_field_accessible?, only: [:vault_token]
  before_filter :validate_associated_tickets, only: [:create]
  before_filter :ignore_unwanted_fields, only: [:create, :update], if: :remove_unrelated_fields?
  before_filter :check_outbound_limit_exceeded, if: :compose_email?

  def create
    assign_protected
    return render_request_error(:recipient_limit_exceeded, 429) if recipients_limit_exceeded?
    ticket_delegator = ticket_delegator_class.new(@item, ticket_fields: @ticket_fields,
                                                         custom_fields: params[cname][:custom_field], tags: cname_params[:tags],
                                                         company_id: params[cname][:company_id], parent_attachment_params: parent_attachment_params,
                                                         inline_attachment_ids: @inline_attachment_ids, version: params[:version],
                                                         enforce_mandatory: params[:enforce_mandatory])
    if !ticket_delegator.valid?(:create)
      render_custom_errors(ticket_delegator, true)
    elsif @item.save_ticket
      @ticket = @item # Dirty hack. Should revisit.
      render_201_with_location(item_id: @item.display_id)
      notify_cc_people @cc_emails[:cc_emails] unless @cc_emails[:cc_emails].blank? || 
                                                     compose_email? || 
                                                     @ticket.import_ticket
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
    delegator_hash = { ticket_fields: @ticket_fields, custom_fields: custom_fields, enforce_mandatory: params[:enforce_mandatory],
                       company_id: params[cname][:company_id], tags: cname_params[:tags], version: params[:version] }
    delegator_hash[:tracker_ticket_id] = cname_params[:tracker_ticket_id] if link_or_unlink?
    delegator_hash[:source] = params[cname][:source]
    ticket_delegator = ticket_delegator_class.new(@item, delegator_hash)
    if !ticket_delegator.valid?(:update)
      render_custom_errors(ticket_delegator, true)
    else
      modify_ticket_associations if link_or_unlink?
      render_errors(@item.errors) unless @item.update_ticket_attributes(params[cname])
    end
  end

  def vault_token
    # Generates vault_token
    jwe = JWT::SecureServiceJWEFactory.new(PciConstants::ACTION[:read], @item.id, PciConstants::PORTAL_TYPE[:agent_portal], PciConstants::OBJECT_TYPE[:ticket])
    @token = jwe.generate_jwe_payload(@secure_field_methods)
    response.api_meta = { vault_token: @token } if private_api?
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

    def secure_field_accessible?
      @secure_field_methods = JWT::SecureFieldMethods.new
      render_request_error :bad_request, 400 unless current_account.secure_fields_enabled? && @secure_field_methods.secure_fields_from_cache.present?
    end

    def feature_name
      FeatureConstants::TICKETS
    end

    def sideload_associations
      @include_validation.include_array.each { |association| increment_api_credit_by(1) }
    end

    def decorator_options(options = {})
      options[:name_mapping] = @name_mapping || (params[:exclude].to_s.include?('custom_fields') ? {} : get_name_mapping)
      options[:sideload_options] = sideload_options.to_a if index? || show?
      options[:custom_fields_mapping] = Account.current.ticket_fields_name_type_mapping_cache
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
      set_all_agent_groups_permission
      if use_public_api_filter_factory?
        items = FilterFactory::TicketFilterer.filter(updated_params, true).preload(conditional_preload_options)
        @items = paginate_items(items, true)
      else
        super tickets_filter.preload(conditional_preload_options)
      end
    end

    def use_public_api_filter_factory?
      return false if params[:filter] && ApiTicketConstants::SPAM_DELETED_FILTER.include?(params[:filter])

      current_account.count_public_api_filter_factory_enabled?
    end

    def updated_params
      {
        data_hash: d_query_hash,
        per_page: per_page,
        page: page,
        order_by: params[:order_by] || ApiTicketConstants::DEFAULT_ORDER_BY,
        order_type: params[:order_type] || ApiTicketConstants::DEFAULT_ORDER_TYPE,
        include: params[:include]
      }.with_indifferent_access
    end

    def paginate_items(items, ff_load = false)
      if ff_load
        add_link_header(page: (page + 1)) if items.length > per_page
        items[0..(per_page - 1)] # get paginated_collection of length 'per_page'
      else
        super(items)
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
      preload_options = [:schema_less_ticket, :tags, { flexifield: [:denormalized_flexifield] }]
      preload_options.push(:ticket_field_data) if Account.current.join_ticket_field_data_enabled?
      @ticket_filter.include_array.each do |assoc|
        preload_options << (ApiTicketConstants::INCLUDE_PRELOAD_MAPPING[assoc.to_sym] || assoc)
        increment_api_credit_by(2) unless assoc.to_s == DESCRIPTION && current_account.description_by_default_enabled?
      end
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

    def paginate_scoper(items, options)
      items.order(options[:order]).paginate(options.except(:order)) # rubocop:disable Gem/WillPaginate
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
      include_description if !description_included? && current_account.description_by_default_enabled?
      params.permit(*ApiTicketConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      @ticket_filter = TicketFilterValidation.new(params, nil, string_request_params?)
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

      params_to_be_deleted = [:cc_emails, :bcc_emails]
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
      reset_nested_fields_params if params[cname][:custom_field] && update?
    end

    def constants_class
      ApiTicketConstants.to_s.freeze
    end

    def remove_unrelated_fields?
      Account.current.launched?(:remove_unrelated_fields)
    end

    def ignore_unwanted_fields
      (params[cname][:custom_field] || []).delete_if do |key, value|
        param_removable?(key)
      end
    end

    def param_removable?(key)
      section_ticket_fields.present? && section_ticket_fields.include?(key) && !possible_custom_fields.include?(key)
    end

    def possible_custom_fields
      @possible_custom_fields ||= begin
        possible_custom_fields_subset = []
        section_picklist_list.each do |picklist_value|
          sec_id = picklist_value.try('section').try('id')
          possible_custom_fields_subset.concat(section_ticket_fields_mapping[sec_id] || [])
        end
        possible_custom_fields_subset
      end
    end

    def section_ticket_fields_mapping
      @section_ticket_fields_mapping ||= begin
        Account.current.section_fields_with_field_values_mapping_cache.inject({}) do |mapping, section_field|
          fields = mapping[section_field.section_id] || []
          fields << section_field.ticket_field.name
          fields << section_field.ticket_field.child_levels.pluck('name') if section_field.ticket_field.nested_field?
          mapping[section_field.section_id] = fields.flatten
          mapping
        end
      end
    end

    def section_ticket_fields
      @section_ticket_fields ||= section_ticket_fields_mapping.values.flatten.compact
    end

    def section_picklist_list
      Account.current.section_parent_fields_from_cache.map do |dropdown_section|
        picklist_values = dropdown_section.picklist_values
        dropdown_section_name = begin
          if dropdown_section.field_type.eql?('default_ticket_type')
            params[cname][:ticket_type] || @item.ticket_type
          else
            params[cname][:custom_field][dropdown_section.name] || (@item.persisted? && @item.safe_send(dropdown_section.name))
          end
        end
        picklist_values.find_by_value(dropdown_section_name) if dropdown_section_name.present?
      end
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
        @item.ticket_body = @item.ticket_body # This will prevent ticket_body query during save
        @item.inline_attachments = @item.inline_attachments
        @item.schema_less_ticket.product ||= current_portal.product unless params[cname].key?(:product_id)
      end
      assign_ticket_status
    end

    def build_attachments
      build_normal_attachments(@item, params[cname][:attachments]) if params[cname][:attachments]
      build_cloud_files(@item, @cloud_files) if private_api? && @cloud_files
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

    def restore?
      @restore ||= current_action?('restore')
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

    def check_outbound_limit_exceeded
      outbound_per_day_key = OUTBOUND_EMAIL_COUNT_PER_DAY % {:account_id => current_account.id }
      total_outbound_per_day = get_others_redis_key(outbound_per_day_key).to_i
      return if ismember?(SPAM_WHITELISTED_ACCOUNTS, current_account.id)
      if (current_account.id > get_spam_account_id_threshold) &&
         current_account.subscription.trial? &&
         total_outbound_per_day >= TRIAL_ACCOUNT_OUTBOUND_DEFAULT_THRESHOLD
        error_info_hash = { count: TRIAL_ACCOUNT_OUTBOUND_DEFAULT_THRESHOLD, details: 'during the trial period' }
        render_request_error_with_info(:outbound_limit_exceeded, 429, error_info_hash, error_info_hash)
      elsif current_account.subscription.free?
        free_threshold = get_free_account_outbound_threshold
        if total_outbound_per_day >= free_threshold
          error_info_hash = { count: free_threshold, details: 'in sprout plan' }
          render_request_error_with_info(:outbound_limit_exceeded, 429, error_info_hash, error_info_hash)
        end
      end
    end

    def recipients_limit_exceeded?
      if current_account.id > get_spam_account_id_threshold &&
         current_account.subscription.trial? &&
         !ismember?(SPAM_WHITELISTED_ACCOUNTS, current_account.id) &&
         (@item.source == Helpdesk::Source::OUTBOUND_EMAIL || @item.source == Helpdesk::Source::PHONE)
        return max_cc_threshold_crossed?
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

    def reset_nested_fields_params
      nested_fields = Account.current.nested_fields_from_cache
      nested_fields.each do |nf|
        first_level_name = nf.name
        second_level_name = nf.nested_ticket_fields.first.name
        third_level = nf.nested_ticket_fields.second
        params[cname][:custom_field][second_level_name] = nil if reset_second_level?(first_level_name, second_level_name)
        params[cname][:custom_field][third_level.name] = nil if third_level_present?(third_level) && reset_third_level?(first_level_name, second_level_name, third_level.name)
      end
    end

    def reset_second_level?(first_level_name, second_level_name)
      reset_param?(first_level_name) && can_be_reset?(second_level_name)
    end

    def reset_third_level?(first_level_name, second_level_name, third_level_name)
      (reset_param?(first_level_name) || reset_param?(second_level_name)) && can_be_reset?(third_level_name)
    end

    def reset_param?(name)
      params[cname][:custom_field][name] && existing_value?(name)
    end

    def existing_value?(name)
      params[cname][:custom_field][name] != @item.custom_field[name]
    end

    def can_be_reset?(name)
      @item.custom_field[name] && !params[cname][:custom_field][name]
    end

    def third_level_present?(third_level)
      third_level.present?
    end

    # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
    wrap_parameters(*wrap_params)
end
