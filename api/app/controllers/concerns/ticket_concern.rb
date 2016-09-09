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

end
