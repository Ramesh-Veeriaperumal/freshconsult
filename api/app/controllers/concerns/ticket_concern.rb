module TicketConcern
  extend ActiveSupport::Concern

  def verify_ticket_permission(user = api_current_user, ticket = @item)
    return true if app_current?
    # Should not allow to update/show/restore/add(or)edit(or)delete(or)show conversations or time_entries to a ticket if ticket is deleted forever or user doesn't have permission
    if (!user.has_ticket_permission?(ticket) && !allow_without_ticket_permission?) || ticket.schema_less_ticket.try(:trashed)
      Rails.logger.error "User: #{user.id}, #{user.email} doesn't have permission to ticket display_id: #{ticket.display_id}"
      render_request_error :access_denied, 403
      return false
    end
    true
  end

  def verify_user_permission(user = api_current_user, item = @item)
    return true if app_current?
    item_user = item && item.user
    unless item && user && item_user && (user.id == item_user.id)
      render_request_error :access_denied, 403
      return false
    end
    true
  end

  def permissible_ticket_ids(id_list)
    @permissible_ids ||= begin
      if api_current_user.can_view_all_tickets?
        id_list
      elsif api_current_user.group_ticket_permission
        tickets_with_group_permission(id_list)
      elsif api_current_user.assigned_ticket_permission
        tickets_with_assigned_permission(id_list)
      else
        []
      end
    end
  end

  def fetch_ticket_fields_mapping
    @ticket_fields = Account.current.ticket_fields_from_cache
    @name_mapping = TicketsValidationHelper.name_mapping(@ticket_fields) # -> {:text_1 => :text}
    @statuses = Helpdesk::TicketStatus.status_objects_from_cache(Account.current)
  end

  private

    def ticket_permission?
      ticket_id = params_ticket_id
      # Should allow to delete ticket based on agents ticket permission privileges.
      unless api_current_user.can_view_all_tickets? || group_ticket_permission?(ticket_id) || assigned_ticket_permission?(ticket_id)
        render_request_error :access_denied, 403
      end
    end

    def params_ticket_id
      params[:ticket_id] || params[:id]
    end

    def group_ticket_permission?(ids)
      # Check if current user has group ticket permission and if ticket also belongs to the same group.
      api_current_user.group_ticket_permission && scoper.group_tickets_permission(api_current_user, ids).present?
    end

    def assigned_ticket_permission?(ids)
      # Check if current user has restricted ticket permission and if ticket also assigned to the current user.
      api_current_user.assigned_ticket_permission && scoper.assigned_tickets_permission(api_current_user, ids).present?
    end

    def tickets_with_group_permission(ids)
      scoper.group_tickets_permission(api_current_user, ids).map(&:display_id)
    end

    def tickets_with_assigned_permission(ids)
      scoper.assigned_tickets_permission(api_current_user, ids).map(&:display_id)
    end

    def ticket_permission_required?
      ApiTicketConstants::PERMISSION_REQUIRED.include?(action_name.to_sym)
    end

    def allow_without_ticket_permission?
      # If there are params other than secondary_ticket_params we should not allow the action as those params don't have access to primary ticket
      # Validations for secondary tickets are done in delegator
      return unless cname_params.present? && secondary_ticket_permission_required?
      secondary_ticket_params = cname_params.keys & ApiTicketConstants::SECONDARY_TICKET_PARAMS
      secondary_ticket_params.present? && secondary_ticket_params.length == cname_params.length
    end

    def secondary_ticket_permission_required?
      cname_params.key?(:tracker_id) && cname_params[:tracker_id].nil?
    end

    def verify_ticket_state_and_permission(user = api_current_user, ticket = @item)
      return false unless verify_object_state(ticket)
      if ticket_permission_required?
        return false unless verify_ticket_permission(user, ticket)
      end

      if ApiTicketConstants::NO_PARAM_ROUTES.include?(action_name) && cname_params.present?
        render_request_error :no_content_required, 400
        return false
      end
      true
    end

    def verify_object_state(ticket = @item)
      action_scopes = ApiTicketConstants::SCOPE_BASED_ON_ACTION[action_name] || ApiTicketConstants::CONDITIONS_FOR_TICKET_ACTIONS
      action_scopes.each_pair do |scope_attribute, value|
        item_value = ticket.safe_send(scope_attribute)
        next if item_value == value
        Rails.logger.debug "Ticket display_id: #{ticket.display_id} with #{scope_attribute} is #{item_value}"
        # Render 405 in case of update/delete as it acts on ticket endpoint itself
        # And User will be able to GET the same ticket via Show
        # other URLs such as tickets/id/restore will result in 404 as it is a separate endpoint
        update? || destroy? ? render_405_error(['GET']) : head(404)
        return false
      end
      true
    end

    def sanitize_ticket_params
      process_ticket_params
      modify_ticket_params
      remove_ticket_params
      process_saved_params
    end

    def process_ticket_params
      prepare_array_fields(ApiTicketConstants::ARRAY_FIELDS - ['tags']) # Tags not included as it requires more manipulation.
      # Set manual due by to override sla worker triggerd updates.
      cname_params[:manual_dueby] = true if cname_params[:due_by] || cname_params[:fr_due_by]
      process_custom_fields
      prepare_tags # Sanitizing is required to avoid duplicate records, we are sanitizing here instead of validating in model to avoid extra query.
      process_requester_params
      process_email_params
      sanitize_cloud_files(cname_params[:cloud_files])
    end

    def modify_ticket_params
      cname_params[:attachments] = cname_params[:attachments].map { |att| { resource: att } } if cname_params[:attachments]
      cname_params[:ticket_body_attributes] = { description_html: cname_params[:description] } if cname_params[:description]
      cname_params[:assoc_parent_tkt_id] = cname_params[:parent_id] if cname_params[:parent_id]
    end

    def process_email_params
      # Assign cc_emails serialized hash & collect it in instance variables as it can't be built properly from params
      cc_emails =  cname_params[:cc_emails]
      # Using .dup as otherwise its stored in reference format(&id0001 & *id001).
      @cc_emails = { cc_emails: cc_emails.dup, fwd_emails: [], reply_cc: cc_emails.dup, tkt_cc: cc_emails.dup } unless cc_emails.nil?
    end

    def remove_ticket_params
      params_to_be_deleted = ApiTicketConstants::PARAMS_TO_REMOVE.dup
      [:due_by, :fr_due_by].each { |key| params_to_be_deleted << key if cname_params[key].nil? }
      ParamsHelper.clean_params(params_to_be_deleted, cname_params)
      ParamsHelper.assign_and_clean_params(ApiTicketConstants::PARAMS_MAPPINGS, cname_params)
      ParamsHelper.save_and_remove_params(self, ApiTicketConstants::PARAMS_TO_SAVE_AND_REMOVE, cname_params)
    end

    def process_saved_params
      # following fields must be handled separately, should not be passed to build_object method
      @attachment_ids = @attachment_ids.map(&:to_i) if @attachment_ids
      @inline_attachment_ids = @inline_attachment_ids.map(&:to_i) if @inline_attachment_ids
    end

    def process_custom_fields
      if cname_params[:custom_fields]
        checkbox_names = TicketsValidationHelper.custom_checkbox_names(@ticket_fields)
        ParamsHelper.assign_checkbox_value(cname_params[:custom_fields], checkbox_names)
      end
    end

    def process_requester_params
      # During update set requester_id to nil if it is not a part of params and if any of the contact detail is given in the params
      if update_action? && !cname_params.key?(:requester_id) && (cname_params.keys & %w(email phone twitter_id facebook_id)).present?
        cname_params[:requester_id] = nil
      end
    end

    def update_action?
      [:update, :update_properties, :bulk_update].include?(action_name.to_sym)
    end
end
