module TicketConcern
  extend ActiveSupport::Concern

  def verify_ticket_permission(user = api_current_user, ticket = @item)
    # Should not allow to update/show/restore/add(or)edit(or)delete(or)show conversations or time_entries to a ticket if ticket is deleted forever or user doesn't have permission
    if !user.has_ticket_permission?(ticket) || ticket.schema_less_ticket.try(:trashed)
      Rails.logger.error "Params: #{params.inspect} User: #{user.id}, #{user.email} doesn't have permission to ticket display_id: #{ticket.display_id}"
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

  private

    def ticket_permission?
      ticket_id = params[:ticket_id] || params[:id]
      # Should allow to delete ticket based on agents ticket permission privileges.
      unless api_current_user.can_view_all_tickets? || group_ticket_permission?(ticket_id) || assigned_ticket_permission?(ticket_id)
        render_request_error :access_denied, 403
      end
    end

    def group_ticket_permission?(ids)
      # Check if current user has group ticket permission and if ticket also belongs to the same group.
      api_current_user.group_ticket_permission && (tickets_scoper || scoper).group_tickets_permission(api_current_user, ids).present?
    end

    def assigned_ticket_permission?(ids)
      # Check if current user has restricted ticket permission and if ticket also assigned to the current user.
      api_current_user.assigned_ticket_permission && (tickets_scoper || scoper).assigned_tickets_permission(api_current_user, ids).present?
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

    def verify_ticket_state_and_permission
      return false unless verify_object_state
      if ticket_permission_required?
        return false unless verify_ticket_permission
      end

      if ApiTicketConstants::NO_PARAM_ROUTES.include?(action_name) && params[cname].present?
        render_request_error :no_content_required, 400
      end
    end

    def verify_object_state
      action_scopes = ApiTicketConstants::SCOPE_BASED_ON_ACTION[action_name] || {}
      action_scopes.each_pair do |scope_attribute, value|
        item_value = @item.send(scope_attribute)
        next if item_value == value
        Rails.logger.debug "Ticket display_id: #{@item.display_id} with #{scope_attribute} is #{item_value}"
        # Render 405 in case of update/delete as it acts on ticket endpoint itself
        # And User will be able to GET the same ticket via Show
        # other URLs such as tickets/id/restore will result in 404 as it is a separate endpoint
        update? || destroy? ? render_405_error(['GET']) : head(404)
        return false
      end
      true
    end
end
