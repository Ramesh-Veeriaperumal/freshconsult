class TicketsController < ApiApplicationController
  wrap_parameters :ticket, exclude: [], format: [:json, :multipart_form]

  include Helpdesk::TicketActions
  include Helpdesk::TagMethods
  include CloudFilesHelper

  before_filter :ticket_permission?, only: [:destroy, :assign]
  before_filter :validate_action_params, only: [:assign, :restore]

  def create
    api_add_tags(@tags, @item) if @tags # Tags need to be built if not already available for the account.
    assign_protected
    ticket_delegator = TicketDelegator.new(@item)
    if !ticket_delegator.valid?
      render_error(ticket_delegator.errors, ticket_delegator.error_options)
    elsif @item.save_ticket
      render_201_with_location(item_id: @item.display_id)
      notify_cc_people @cc_emails[:cc_emails] unless @cc_emails[:cc_emails].blank?
    else
      render_error(@item.errors)
    end
  end

  def update
    assign_protected 

    # Assign attributes required as the ticket delegator needs it.
    @item.assign_attributes(params[cname])
    ticket_delegator = TicketDelegator.new(@item)
    if !ticket_delegator.valid?
      set_custom_errors(ticket_delegator)
      render_error(ticket_delegator.errors, ticket_delegator.error_options)
    elsif @item.update_ticket_attributes(params[cname])
      api_update_tags(@tags, @item) if @tags # add tags if update is successful.
      notify_cc_people @new_cc_emails unless @new_cc_emails.blank? # notify cc_people on update too.
    else
      render_error(@item.errors)
    end
  end

  def destroy
    @item.update_attribute(:deleted, true)
    head 204
  end

  def assign
    # can unassign an agent too. Should support that too.
    user = params[cname][:user_id] ? User.find_by_id(params[cname][:user_id]) : current_user
    if user
      @item.responder = user
      @item.save ? (head 204) : render_error(@item.errors)
    else
      @errors = [BadRequestError.new('responder', "can't be blank")]
      render '/bad_request_error', status: 400
    end
  end

  def restore
    @item.update_attribute(:deleted, false)
    head 204
  end

  def show
    @notes = ticket_notes.limit(NoteConstants::MAX_INCLUDE) if params[:include] == 'notes'
    super
  end

  private

    def set_custom_erros(item = @item)
      ErrorHelper.rename_error_fields({ group: :group_id, responder: :responder_id, requester: :requester_id, email_config: :email_config_id,
                                        product: :product_id }, item)
    end

    def load_objects
      super tickets_filter(scoper).includes(:ticket_old_body,
                                            :schema_less_ticket, flexifield: :flexifield_def)
    end

    def after_load_object
      verify_ticket_permission if show? || update?
    end

    def ticket_notes
      # eager_loading note_old_body is unnecessary if all notes are retrieved from cache.
      # There is no best solution for this
      @item.notes.visible.exclude_source('meta').includes(:schema_less_note, :note_old_body, :attachments)
    end

    def paginate_options
      options = super

      # this being used by notes/time_sheets action also. Hence order options based on action.
      options[:order] = order_clause if ApiTicketConstants::ORDER_BY_SCOPE["#{action_name}"]
      options
    end

    def order_clause
      order_by =  params[:order_by] || 'created_at'
      order_type = params[:order_type] || 'desc'
      "helpdesk_tickets.#{order_by} #{order_type} "
    end

    def tickets_filter(tickets)
      tickets = tickets.where(deleted: false, spam: false).permissible(current_user)
      @ticket_filter.conditions.each do |key|
        clause = Helpdesk::Ticket.api_filter(@ticket_filter, current_user)[key.to_sym] || {}
        tickets = tickets.where(clause[:conditions]).joins(clause[:joins])
      end
      tickets
    end

    def validate_filter_params
      params.permit(*ApiTicketConstants::INDEX_TICKET_FIELDS, *ApiConstants::DEFAULT_PARAMS,
                    *ApiConstants::DEFAULT_INDEX_FIELDS)
      @ticket_filter = TicketFilterValidation.new(params)
      render_error(@ticket_filter.errors, @ticket_filter.error_options) unless @ticket_filter.valid?
    end

    def scoper
      current_account.tickets
    end

    def validate_action_params
      params[cname].permit(*("ApiTicketConstants::#{params[:action].upcase}_TICKET_FIELDS".constantize))
    end

    def validate_url_params
      params.permit(*ApiTicketConstants::SHOW_TICKET_FIELDS, *ApiConstants::DEFAULT_PARAMS)
      if ApiTicketConstants::ALLOWED_INCLUDE_PARAMS.exclude?(params[:include])
        errors = [[:include, ["can't be blank"]]]
        render_error errors
      end
    end

    def manipulate_params
      # Assign cc_emails serialized hash & collect it in instance variables as it can't be built properly from params
      cc_emails =  (params[cname][:cc_emails] || [])

      # Using .dup as otherwise its stored in reference format(&id0001 & *id001).
      @cc_emails = { cc_emails: cc_emails.dup, fwd_emails: [], reply_cc: cc_emails.dup }

      # Set manual due by to override sla worker triggerd updates.
      params[cname][:manual_dueby] = true if params[cname][:due_by] || params[cname][:fr_due_by]

      # Collect tags in instance variable as it should not be part of params before build item.
      @tags = Array.wrap(params[cname][:tags]).map! { |x| x.to_s.strip } if params[cname].key?(:tags)

      # Assign original fields from api params and clean api params.
      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field, fr_due_by: :frDueBy,
                                             type: :ticket_type }, params[cname])
      ParamsHelper.clean_params([:cc_emails, :tags], params[cname])

      # build ticket body attributes from description and description_html
      build_ticket_body_attributes
      params[cname][:attachments] = params[cname][:attachments].map { |att| { resource: att } } if params[cname][:attachments]
    end

    def validate_params
      allowed_custom_fields = Helpers::TicketsValidationHelper.ticket_custom_field_keys
      # Should not allow any key value pair inside custom fields hash if no custom fields are available for accnt.
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields
      field = ApiTicketConstants::TICKET_FIELDS | ['custom_fields' => custom_fields]
      params[cname].permit(*(field))
      ticket = TicketValidation.new(params[cname], @item)
      render_error ticket.errors, ticket.error_options unless ticket.valid?
    end

    def assign_protected
      @item.product ||= current_portal.product
      @item.account = current_account
      @new_cc_emails = @cc_emails[:cc_emails] - (@item.cc_email.try(:[], :cc_emails) || []) if update?
      @item.cc_email = @cc_emails
      build_normal_attachments(@item, params[cname][:attachments]) if params[cname][:attachments]
      @item.attachments = @item.attachments if create? # assign attachments so that it will not be queried again in model callbacks
    end

    def verify_ticket_permission
      # Should not allow to update ticket if item is deleted forever or current_user doesn't have permission
      render_request_error :access_denied, 403 unless current_user.has_ticket_permission?(@item) && !@item.schema_less_ticket.try(:trashed)
    end

    def ticket_permission?
      # Should allow to delete ticket based on agents ticket permission privileges.
      unless current_user.can_view_all_tickets? || group_ticket_permission?(params[:id]) || assigned_ticket_permission?(params[:id])
        render_request_error :access_denied, 403
      end
    end

    def group_ticket_permission?(ids)
      # Check if current user has group ticket permission and if ticket also belongs to the same group.
      current_user.group_ticket_permission && scoper.group_tickets_permission(current_user, ids).present?
    end

    def assigned_ticket_permission?(ids)
      # Check if current user has restricted ticket permission and if ticket also assigned to the current user.
      current_user.assigned_ticket_permission && scoper.assigned_tickets_permission(current_user, ids).present?
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
      condition = 'display_id = ? '
      condition += "and deleted = #{ApiConstants::DELETED_SCOPE[action_name]}" if ApiConstants::DELETED_SCOPE.keys.include?(action_name)
      @item = scoper.where(condition, params[:id]).first
      head(:not_found) unless @item
    end
end
