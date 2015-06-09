class TicketsController < ApiApplicationController
  wrap_parameters :ticket, exclude: [], format: [:json, :multipart_form]

  include Helpdesk::TicketActions
  include Concerns::TicketConcern
  include Helpdesk::TagMethods
  include CloudFilesHelper
  include Utils::Unhtml

  before_filter :assign_protected, only: [:create, :update]
  before_filter :verify_ticket_permission, only: [:update, :show]
  before_filter :has_ticket_permission?, only: [:destroy, :assign]
  before_filter :restrict_params, only: [:assign, :restore]

  def create
    add_ticket_tags(@tags, @item) if @tags # Tags need to be built if not already available for the account.
    build_normal_attachments(@item, params[cname][:attachments])
    if @item.save_ticket
      render '/tickets/create', location: send("#{nscname}_url", @item.id), status: 201
      notify_cc_people params[cname][:cc_email] unless params[cname][:cc_email].blank?
    else
      set_custom_errors
      @error_options ? render_custom_errors(@item, @error_options) : render_error(@item.errors)
    end
  end

  def update
    build_normal_attachments(@item, params[cname][:attachments])
    if @item.update_ticket_attributes(params[cname])
      update_tags(@tags, true, @item) if @tags # add tags if update is successful.
    else
      set_custom_errors
      @error_options ? render_custom_errors(@item, @error_options) : render_error(@item.errors)
    end
  end

  def destroy
    if @item.update_attributes(deleted: true)
      head 204
    else
      set_custom_errors
      @error_options ? render_custom_errors(@item, @error_options) : render_error(@item.errors)
    end
  end

  def assign
    user = params[cname][:user_id] ? User.find_by_id(params[cname][:user_id]) : current_user
    if user
      @ticket.responder = user
      @ticket.save ? (head 204) : render_error(@item.errors)
    else
      @errors = [BadRequestError.new('responder', "can't be blank")]
      render '/bad_request_error', status: 400
    end
  end

  def restore
    if @ticket.update_attribute(:deleted, false)
      head 204
    else
      render_error(@item.errors)
    end
  end

  private

    def scoper
      current_account.tickets
    end

    def restrict_params
      params[cname].permit(*("ApiConstants::#{params[:action].upcase}_TICKET_FIELDS".constantize))
    end

    def manipulate_params
      # Assign cc_emails serialized hash
      cc_emails =  params[cname][:cc_emails] || []
      params[cname][:cc_email] = { cc_emails: cc_emails, fwd_emails: [], reply_cc: cc_emails } unless @item
      # Set manual due by to override sla worker triggerd updates.
      params[cname][:manual_dueby] = true if params[cname][:due_by] && params[cname][:fr_due_by]
      # Collect tags in instance variable as it should not be part of params before build item.
      @tags = params[cname][:tags] if params[cname][:tags]
      # Assign original fields from api params and clean api params.
      assign_and_clean_params(custom_fields: :custom_field, fr_due_by: :frDueBy, type: :ticket_type)
      clean_params([:cc_emails, :tags])
      # build ticket body attributes from description and description_html
      build_ticket_body_attributes
      params[cname][:attachments] = params[cname][:attachments].map { |att| { resource: att } } if params[cname][:attachments]
    end

    def validate_params
      allowed_custom_fields = TicketsValidationHelper.ticket_custom_field_keys(current_account)
      # Should not allow any key value pair inside custom fields hash if no custom fields are available for accnt.
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields
      field = "ApiConstants::#{action_name.upcase}_TICKET_FIELDS".constantize | ['custom_fields' => custom_fields]
      params[cname].permit(*(field))
      ticket = TicketValidation.new(params[cname], @item, current_account)
      render_error ticket.errors unless ticket.valid?
    end

    def assign_protected
      @item.product ||= current_portal.product
    end

    def assign_and_clean_params(params_hash)
      # Assign original fields with api params
      params_hash.each_pair do |api_field, attr_field|
        params[cname][attr_field] = params[cname][api_field] if params[cname][api_field]
      end
      clean_params(params_hash.keys)
    end

    def clean_params(params_to_be_deleted)
      params_to_be_deleted.each do |field|
        params[cname].delete(field)
      end
    end

    def verify_ticket_permission
      # Should not allow to update ticket if item is deleted forever or current_user doesn't have permission
      render_request_error :access_denied, 403 unless current_user.has_ticket_permission?(@item) && !@item.trashed
    end

    def has_ticket_permission?
      # Should allow to delete ticket based on agents ticket permission privileges.
      unless current_user.can_view_all_tickets? || has_group_ticket_permission?(params[:id]) || has_assigned_ticket_permission?(params[:id])
        render_request_error :access_denied, 403
      end
    end

    def has_group_ticket_permission?(ids)
      # Check if current user has group ticket permission and if ticket also belongs to the same group.
      current_user.group_ticket_permission && scoper.group_tickets_permission(current_user, ids).present?
    end

    def has_assigned_ticket_permission?(ids)
      # Check if current user has restricted ticket permission and if ticket also assigned to the current user.
      current_user.assigned_ticket_permission && scoper.assigned_tickets_permission(current_user, ids).present?
    end

    def load_object
      condition = 'display_id = ? '
      condition += "and deleted = #{ApiConstants::DELETED_SCOPE[action_name]}" if ApiConstants::DELETED_SCOPE.keys.include?(action_name)
      item = scoper.where(condition, params[:id]).first
      @item = instance_variable_set('@' + cname, item)
      head :not_found unless @item
    end
end
