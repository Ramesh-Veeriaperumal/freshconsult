class TicketsController < ApiApplicationController
  include Helpdesk::TicketActions
  include Helpdesk::TagMethods
  include CloudFilesHelper
  include TicketConcern
  include SearchHelper
  include Search::Filters::QueryHelper
  decorate_views(decorate_objects: [:index, :search])

  around_filter :run_on_slave, only: [:index]

  before_filter :ticket_permission?, only: [:destroy]
  before_filter :check_search_feature, :validate_search_params, only: [:search]

  def create
    assign_protected
    ticket_delegator = TicketDelegator.new(@item, ticket_fields: @ticket_fields, custom_fields: params[cname][:custom_field])
    if !ticket_delegator.valid?(:create)
      render_custom_errors(ticket_delegator, true)
    else
      if @item.save_ticket
        @ticket = @item # Dirty hack. Should revisit.
        render_201_with_location(item_id: @item.display_id)
        notify_cc_people @cc_emails[:cc_emails] unless @cc_emails[:cc_emails].blank? || compose_email?
      else
        render_errors(@item.errors)
      end
    end
  end

  def update
    assign_protected
    # Assign attributes required as the ticket delegator needs it.
    custom_fields = params[cname][:custom_field] # Assigning it here as it would be deleted in the next statement while assigning.
    @item.assign_attributes(validatable_delegator_attributes)
    @item.assign_description_html(params[cname][:ticket_body_attributes]) if params[cname][:ticket_body_attributes]
    delegator_hash = { ticket_fields: @ticket_fields, custom_fields: custom_fields,
                       company_id: params[cname][:company_id] }
    ticket_delegator = TicketDelegator.new(@item, delegator_hash)
    if !ticket_delegator.valid?(:update)
      render_custom_errors(ticket_delegator, true)
    else
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
      return if !compose_email? || Account.current.compose_email_enabled?
      render_request_error(:require_feature, 403, feature: feature.to_s.titleize)
    end

  private

    # Same as http://apidock.com/rails/Hash/extract! without the shortcomings in http://apidock.com/rails/Hash/extract%21#1530-Non-existent-key-semantics-changed-
    # extract the keys from the hash & delete the same in the original hash to avoid repeat assignments
    def validatable_delegator_attributes
      params[cname].select do |key, value|
        (params[cname].delete(key); true) if ApiTicketConstants::VALIDATABLE_DELEGATOR_ATTRIBUTES.include?(key)
      end
    end

    def feature_name
      FeatureConstants::TICKETS
    end

    def sideload_associations
      @include_validation.include_array.each { |association| increment_api_credit_by(1) }
    end

    def decorator_options
      options =  { name_mapping: (@name_mapping || get_name_mapping) }
      options.merge!(sideload_options: sideload_options.to_a) if index? || show?
      super(options)
    end

    def get_name_mapping
      # will be called only for index and show.
      # We want to avoid memcache call to get custom_field keys and hence following below approach.
      mapping = Account.current.ticket_field_def.ff_alias_column_mapping
      mapping.each_with_object({}) { |(ff_alias, column), hash| hash[ff_alias] = TicketDecorator.display_name(ff_alias) } if @item || @items.present?
    end

    def sideload_options
      index? ? @ticket_filter.include_array : @include_validation.include_array
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields(field_mappings, item)
    end

    def load_objects
      Rails.logger.info ":::Loading objects started:::"
      super tickets_filter.preload(conditional_preload_options)
      Rails.logger.info ":::Loading objects done:::"
    end

    def conditional_preload_options
      preload_options = [:ticket_old_body, :schema_less_ticket, :flexifield]
      @ticket_filter.include_array.each do |assoc|
        preload_options << (ApiTicketConstants::INCLUDE_PRELOAD_MAPPING[assoc] || assoc)
        increment_api_credit_by(2)
      end
      Rails.logger.info ":::preloads: #{preload_options.inspect}"
      preload_options
    end

    def after_load_object
      return false unless verify_object_state
      if show? || update? || restore?
        return false unless verify_ticket_permission
      end

      if ApiTicketConstants::NO_PARAM_ROUTES.include?(action_name) && params[cname].present?
        render_request_error :no_content_required, 400
      end
    end

    def paginate_options(is_array = false)
      options = super(is_array)
      options[:order] = order_clause
      options
    end

    def order_clause
      order_by =  params[:order_by] || ApiTicketConstants::DEFAULT_ORDER_BY
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
      conditions.merge!(spam: false) unless filter_conditions.include?(:deleted)
      conditions
    end

    def validate_filter_params
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

    def scoper
      current_account.tickets
    end

    def validate_url_params
      params.permit(*ApiTicketConstants::SHOW_FIELDS, *ApiConstants::DEFAULT_PARAMS)
      @include_validation = TicketIncludeValidation.new(params)
      render_errors @include_validation.errors, @include_validation.error_options unless @include_validation.valid?
    end

    def sanitize_params
      prepare_array_fields [:cc_emails, :attachments] # Tags not included as it requires more manipulation.

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

      params_to_be_deleted = [:cc_emails]
      [:due_by, :fr_due_by].each { |key| params_to_be_deleted << key if params[cname][key].nil? }
      ParamsHelper.clean_params(params_to_be_deleted, params[cname])

      # Assign original fields from api params and clean api params.
      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field, fr_due_by: :frDueBy,
                                             type: :ticket_type }, params[cname])

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

    def validate_params
      # We are obtaining the mapping in order to swap the field names while rendering(both successful and erroneous requests), instead of formatting the fields again.
      @ticket_fields = Account.current.ticket_fields_from_cache
      @name_mapping = TicketsValidationHelper.name_mapping(@ticket_fields) # -> {:text_1 => :text}
      # Should not allow any key value pair inside custom fields hash if no custom fields are available for accnt.
      custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
      field = "ApiTicketConstants::#{original_action_name.upcase}_FIELDS".constantize | ['custom_fields' => custom_fields]
      params[cname].permit(*(field))
      set_default_values
      params_hash = params[cname].merge(statuses: Helpdesk::TicketStatus.status_objects_from_cache(current_account), ticket_fields: @ticket_fields)
      ticket = TicketValidation.new(params_hash, @item, string_request_params?)
      render_custom_errors(ticket, true) unless ticket.valid?(original_action_name.to_sym)
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
      build_normal_attachments(@item, params[cname][:attachments]) if params[cname][:attachments]
      if create? # assign attachments so that it will not be queried again in model callbacks
        @item.attachments = @item.attachments
        @item.ticket_old_body = @item.ticket_old_body # This will prevent ticket_old_body query during save
        @item.inline_attachments = @item.inline_attachments
        @item.schema_less_ticket.product ||= current_portal.product unless params[cname].key?(:product_id)
      end
      assign_ticket_status
    end

    def verify_object_state
      action_scopes = ApiTicketConstants::SCOPE_BASED_ON_ACTION[action_name] || {}
      action_scopes.each_pair do |scope_attribute, value|
        item_value = @item.safe_send(scope_attribute)
        if item_value != value
          Rails.logger.debug "Ticket display_id: #{@item.display_id} with #{scope_attribute} is #{item_value}"
          # Render 405 in case of update/delete as it acts on ticket endpoint itself
          # And User will be able to GET the same ticket via Show
          # other URLs such as tickets/id/restore will result in 404 as it is a separate endpoint
          update? || destroy? ? render_405_error(['GET']) : head(404)
          return false
        end
      end
      true
    end

    def ticket_permission?
      # Should allow to delete ticket based on agents ticket permission privileges.
      unless api_current_user.can_view_all_tickets? || group_ticket_permission?(params[:id]) || assigned_ticket_permission?(params[:id])
        render_request_error :access_denied, 403
      end
    end

    def check_search_feature
      log_and_render_404 unless current_account.launched?(:api_search_beta)
    end

    def group_ticket_permission?(ids)
      # Check if current user has group ticket permission and if ticket also belongs to the same group.
      api_current_user.group_ticket_permission && scoper.group_tickets_permission(api_current_user, ids).present?
    end

    def assigned_ticket_permission?(ids)
      # Check if current user has restricted ticket permission and if ticket also assigned to the current user.
      api_current_user.assigned_ticket_permission && scoper.assigned_tickets_permission(api_current_user, ids).present?
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

    def field_mappings
      (custom_field_error_mappings || {}).merge(ApiTicketConstants::FIELD_MAPPINGS)
    end
    # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
    wrap_parameters(*wrap_params)
end
