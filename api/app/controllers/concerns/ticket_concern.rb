module TicketConcern
  extend ActiveSupport::Concern

  def verify_ticket_permission(user = api_current_user, ticket = @item)
    # Should not allow to update/show/restore/add(or)edit(or)delete(or)show notes or time_entries to a ticket if ticket is deleted forever or user doesn't have permission
    if !user.has_ticket_permission?(ticket) || ticket.schema_less_ticket.try(:trashed)
      Rails.logger.error "Params: #{params.inspect} User: #{user.id}, #{user.email} doesn't have permission to ticket display_id: #{ticket.display_id}"
      render_request_error :access_denied, 403
      return false
    end
    true
  end
end
