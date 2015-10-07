class TicketsController < ApiApplicationController
  include Helpdesk::TicketActions
  include Helpdesk::TagMethods
  include CloudFilesHelper
  include TicketConcern

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
    elsif @item.update_ticket_attributes(params[cname])
      notify_cc_people @new_cc_emails unless @new_cc_emails.blank?
    else
      render_errors(@item.errors)
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
    @notes = ticket_notes.limit(NoteConstants::MAX_INCLUDE) if params[:include] == 'notes'
    super
  end

  def self.wrap_params
    ApiTicketConstants::WRAP_PARAMS
  end

  private

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields({ group: :group_id, responder: :responder_id, requester: :requester_id, email_config: :email_config_id,
                                        product: :product_id }, item)
    end

    def load_objects
      super tickets_filter.includes(:ticket_old_body,
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
      @item.notes.visible.exclude_source('meta').includes(:schema_less_note, :note_old_body, :attachments)
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
      tickets = scoper.where(deleted: false, spam: false).permissible(api_current_user)
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
      @ticket_filter = TicketFilterValidation.new(params.merge(multipart_params))
      render_errors(@ticket_filter.errors, @ticket_filter.error_options) unless @ticket_filter.valid?
    end

    def scoper
      current_account.tickets
    end

    def validate_url_params
      params.permit(*ApiTicketConstants::SHOW_FIELDS, *ApiConstants::DEFAULT_PARAMS)
      if ApiTicketConstants::ALLOWED_INCLUDE_PARAMS.exclude?(params[:include])
        errors = [[:include, ["can't be blank"]]]
        render_errors errors
      end
    end

    def sanitize_params
      prepare_array_fields [:cc_emails, :tags, :attachments]

      # Assign cc_emails serialized hash & collect it in instance variables as it can't be built properly from params
      cc_emails =  params[cname][:cc_emails]

      # Using .dup as otherwise its stored in reference format(&id0001 & *id001).
      @cc_emails = { cc_emails: cc_emails.dup, fwd_emails: [], reply_cc: cc_emails.dup } unless cc_emails.nil?

      # Set manual due by to override sla worker triggerd updates.
      params[cname][:manual_dueby] = true if params[cname][:due_by] || params[cname][:fr_due_by]
      assign_checkbox_value if params[cname][:custom_fields]

      # Assign original fields from api params and clean api params.
      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field, fr_due_by: :frDueBy,
                                             type: :ticket_type }, params[cname])
      ParamsHelper.clean_params([:cc_emails], params[cname])

      @tags = Array.wrap(params[cname][:tags]).map! { |x| x.to_s.strip } if params[cname].key?(:tags)
      params[cname][:tags] = construct_tags(@tags) if @tags

      # build ticket body attributes from description and description_html
      build_ticket_body_attributes
      params[cname][:attachments] = params[cname][:attachments].map { |att| { resource: att } } if params[cname][:attachments]
    end

    def validate_params
      @ticket_fields = Account.current.ticket_fields_from_cache
      allowed_custom_fields = Helpers::TicketsValidationHelper.ticket_custom_field_keys(@ticket_fields)
      # Should not allow any key value pair inside custom fields hash if no custom fields are available for accnt.
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields
      field = ApiTicketConstants::FIELDS | ['custom_fields' => custom_fields]
      params[cname].permit(*(field))
      load_ticket_status # loading ticket status to avoid multiple queries in model.
      params_hash = params[cname].merge(status_ids: @statuses.map(&:status_id), ticket_fields: @ticket_fields)
      ticket = TicketValidation.new(params_hash.merge(multipart_params), @item)
      render_errors ticket.errors, ticket.error_options unless ticket.valid?
    end

    def assign_protected
      @item.product ||= current_portal.product
      @item.account = current_account
      unless @cc_emails.nil?
        @new_cc_emails = @cc_emails[:cc_emails] - (@item.cc_email.try(:[], :cc_emails) || []) if update?
        @item.cc_email = @cc_emails
      end
      build_normal_attachments(@item, params[cname][:attachments]) if params[cname][:attachments]
      if create? # assign attachments so that it will not be queried again in model callbacks
        @item.attachments = @item.attachments
        @item.inline_attachments = @item.inline_attachments
      end
    end

    def verify_object_state
      action_scopes = ApiTicketConstants::SCOPE_BASED_ON_ACTION[action_name] || {}
      action_scopes.each_pair do |scope_attribute, value|
        if @item.send(scope_attribute) != value
          head(404)
          return false
        end
      end
      true
    end

    # If false given, nil is getting saved in db as there is nil assignment if blank in flexifield. Hence assign 0
    def assign_checkbox_value
      check_box_names = Helpers::TicketsValidationHelper.check_box_type_custom_field_names(@ticket_fields)
      params[cname][:custom_fields].each_pair do |key, value|
        next unless check_box_names.include?(key.to_s)
        params[cname][:custom_fields][key] = 0 if value.is_a?(FalseClass) || value == 'false'
      end
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
      head(:not_found) unless @item
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

    # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
    wrap_parameters(*wrap_params)
end
