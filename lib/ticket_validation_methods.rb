module TicketValidationMethods
	include Helpdesk::Ticketfields::TicketStatus
  include Redis::RedisKeys
  include Redis::OthersRedis

  def log_error ticket
    Rails.logger.debug "validation failed for ##{ticket.display_id} Errors #{ticket.errors.full_messages.inspect}"
  end

  def items_empty?
    @items.nil?
  end

  def remove_from_params ticket
    params[:ids] = params[:ids] - [ticket.display_id.to_s]
    @items = @items - [ticket]
    @failed_tickets << ticket.display_id
    log_error(ticket)
  end

  def close_action? status
    [CLOSED, RESOLVED].include? status.to_i
  end

  def valid_ticket? ticket
    ticket.required_fields_on_closure = true
    valid = ticket.valid?
    ticket.required_fields_on_closure = false
    valid
  end  

end
