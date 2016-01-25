class TicketsController < ApiApplicationController
  include Helpdesk::TicketActions
  include Helpdesk::TagMethods
  include CloudFilesHelper
  include TicketConcern
  decorate_views

  before_filter :ticket_permission?, only: [:destroy]

  def create
    assign_protected
    ticket_delegator = TicketDelegator.new(@item, ticket_fields: @ticket_fields)
    if !ticket_delegator.valid?(:create)
      render_custom_errors(ticket_delegator, true)
    else
      assign_ticket_status
      if @item.save_ticket
        render_201_with_location(item_id: @item.display_id)
        @ticket = @item
        notify_cc_people @cc_emails[:cc_emails] unless @cc_emails[:cc_emails].blank?
      else
        render_errors(@item.errors)
      end
    end
  end

  def update
    assign_protected
    # Assign attributes required as the ticket delegator needs it.
    @item.assign_attributes(params[cname].slice(*ApiTicketConstants::DELEGATOR_ATTRIBUTES))
    @item.assign_description_html(params[cname][:ticket_body_attributes]) if params[cname][:ticket_body_attributes]
    ticket_delegator = TicketDelegator.new(@item, ticket_fields: @ticket_fields)
    if !ticket_delegator.valid?(:update)
      render_custom_errors(ticket_delegator, true)
    else
      render_errors(@item.errors) unless @item.update_ticket_attributes(params[cname])
    end
  end

  def destroy
    @item.update_attribute(:deleted, true)
    head 204
  end

  def restore
    @item.update_attribute(:deleted, false)
    head 204
  end

  def show
    if params[:include] == 'notes'
      @notes = ticket_notes.limit(NoteConstants::MAX_INCLUDE)
      increment_api_credit_by(1) # for embedded notes
    end
    super
  end

  def self.wrap_params
    ApiTicketConstants::WRAP_PARAMS
  end

  private

    def decorator_options
      super({ name_mapping: (@name_mapping || get_name_mapping) })
    end

    def get_name_mapping
      # will be called only for index and show.
      # We want to avoid memcache call to get custom_field keys and hence following below approach.
      custom_field = index? ? @items.first.try(:custom_field) : @item.custom_field
      custom_field.each_with_object({}) { |(name, value), hash| hash[name] = TicketDecorator.display_name(name) } if custom_field
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields(ApiTicketConstants::FIELD_MAPPINGS.merge(@name_mapping), item)
    end

    def load_objects
      super tickets_filter.preload(:ticket_old_body,
                                   :schema_less_ticket, flexifield: { flexifield_def: :flexifield_def_entries })
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

    def ticket_notes
      # eager_loading note_old_body is unnecessary if all notes are retrieved from cache.
      # There is no best solution for this
      @item.notes.visible.exclude_source('meta').preload(:schema_less_note, :note_old_body, :attachments).order(:created_at)
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
      tickets = scoper.where(deleted: false).permissible(api_current_user)
      filter = Helpdesk::Ticket.filter_conditions(@ticket_filter, api_current_user)
      @ticket_filter.conditions.each do |key|
        clause = filter[key.to_sym] || {}
        tickets = tickets.where(clause[:conditions]).joins(clause[:joins])
        # method chaining is done here as, clause[:conditions] could be an array or a hash
      end
      tickets
    end

    def validate_filter_params
      params.permit(*ApiTicketConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      @ticket_filter = TicketFilterValidation.new(params, nil, string_request_params?)
      render_query_param_errors(@ticket_filter.errors, @ticket_filter.error_options) unless @ticket_filter.valid?
    end

    def scoper
      current_account.tickets
    end

    def validate_url_params
      params.permit(*ApiTicketConstants::SHOW_FIELDS, *ApiConstants::DEFAULT_PARAMS)
      if params.key?(:include) && ApiTicketConstants::ALLOWED_INCLUDE_PARAMS.exclude?(params[:include])
        errors = [[:include, :not_included]]
        render_errors errors, list: ApiTicketConstants::ALLOWED_INCLUDE_PARAMS.join(', ')
      end
    end

    def sanitize_params
      prepare_array_fields [:cc_emails, :attachments] # Tags not included as it requires more manipulation.

      # Assign cc_emails serialized hash & collect it in instance variables as it can't be built properly from params
      cc_emails =  params[cname][:cc_emails]

      # Using .dup as otherwise its stored in reference format(&id0001 & *id001).
      @cc_emails = { cc_emails: cc_emails.dup, fwd_emails: [], reply_cc: cc_emails.dup } unless cc_emails.nil?

      # Set manual due by to override sla worker triggerd updates.
      params[cname][:manual_dueby] = true if params[cname][:due_by] || params[cname][:fr_due_by]

      if params[cname][:custom_fields]
        checkbox_names = Helpers::TicketsValidationHelper.custom_checkbox_names(@ticket_fields)
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
    end

    def prepare_tags
      tags = Array.wrap(params[cname][:tags]).map! { |x| RailsFullSanitizer.sanitize(x.to_s.strip) }.uniq(&:downcase).reject(&:blank?) if create? || params[cname].key?(:tags)
      params[cname][:tags] = construct_tags(tags) if tags
    end

    def validate_params
      # We are obtaining the mapping in order to swap the field names while rendering(both successful and erroneous requests), instead of formatting the fields again.
      @ticket_fields = Account.current.ticket_fields_from_cache
      @name_mapping = Helpers::TicketsValidationHelper.name_mapping(@ticket_fields) # -> {:text_1 => :text}
      # Should not allow any key value pair inside custom fields hash if no custom fields are available for accnt.
      custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
      field = "ApiTicketConstants::#{action_name.upcase}_FIELDS".constantize | ['custom_fields' => custom_fields]
      params[cname].permit(*(field))
      ParamsHelper.modify_custom_fields(params[cname][:custom_fields], @name_mapping.invert) # Using map instead of invert does not show any perf improvement.
      load_ticket_status # loading ticket status to avoid multiple queries in model.
      params_hash = params[cname].merge(status_ids: @statuses.map(&:status_id), ticket_fields: @ticket_fields)
      ticket = TicketValidation.new(params_hash, @item, string_request_params?)
      render_custom_errors(ticket, true) unless ticket.valid?
    end

    def assign_protected
      @item.account = current_account
      @item.cc_email = @cc_emails unless @cc_emails.nil?
      build_normal_attachments(@item, params[cname][:attachments]) if params[cname][:attachments]
      if create? # assign attachments so that it will not be queried again in model callbacks
        @item.attachments = @item.attachments
        @item.inline_attachments = @item.inline_attachments
        @item.product ||= current_portal.product unless params[cname].key?(:product_id)
      end
    end

    def verify_object_state
      action_scopes = ApiTicketConstants::SCOPE_BASED_ON_ACTION[action_name] || {}
      action_scopes.each_pair do |scope_attribute, value|
        item_value = @item.send(scope_attribute)
        if item_value != value
          Rails.logger.debug "Ticket display_id: #{@item.display_id} with #{scope_attribute} is #{item_value}"
          head(404)
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

    def group_ticket_permission?(ids)
      # Check if current user has group ticket permission and if ticket also belongs to the same group.
      api_current_user.group_ticket_permission && scoper.group_tickets_permission(api_current_user, ids).present?
    end

    def assigned_ticket_permission?(ids)
      # Check if current user has restricted ticket permission and if ticket also assigned to the current user.
      api_current_user.assigned_ticket_permission && scoper.assigned_tickets_permission(api_current_user, ids).present?
    end

    def build_ticket_body_attributes
      if params[cname][:description] || params[cname][:description_html]
        ticket_body_hash = { ticket_body_attributes: { description: params[cname][:description],
                                                       description_html: params[cname][:description_html] } }
        params[cname].merge!(ticket_body_hash).tap do |t|
          t.delete(:description) if t[:description]
          t.delete(:description_html) if t[:description_html]
        end
      end
    end

    def load_object
      @item = scoper.find_by_display_id(params[:id])
      log_and_render_404 unless @item
    end

    def load_ticket_status
      @statuses = Helpdesk::TicketStatus.status_objects_from_cache(current_account)
    end

    def assign_ticket_status
      @item.status = OPEN unless @item.status_changed?
      @item.ticket_status = @statuses.find { |x| x.status_id == @item.status }
    end

    def restore?
      @restore ||= current_action?('restore')
    end

    def error_options_mappings
      @name_mapping.merge(ApiTicketConstants::FIELD_MAPPINGS)
    end

    def valid_content_type?
      return true if super
      allowed_content_types = ApiTicketConstants::ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym] || [:json]
      allowed_content_types.include?(request.content_mime_type.ref)
    end

    # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
    wrap_parameters(*wrap_params)
end
