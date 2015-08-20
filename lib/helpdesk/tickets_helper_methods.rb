module Helpdesk::TicketsHelperMethods

  include Helpdesk::Ticketfields::TicketStatus  
  
  def subject_style(ticket,onhold_and_closed_statuses)
    if ticket.outbound_email?
      cust_responded = customer_responded_for_outbound?(ticket) 
    else
      cust_responded = customer_responded_to_ticket?(ticket)
    end
    overdue = ticket_overdue?(ticket,onhold_and_closed_statuses)
    ticket_active = ticket.active?
    type = "customer_responded" if cust_responded and ticket_active
    type = "new" if new_ticket?(ticket,onhold_and_closed_statuses) and !ticket.outbound_email?
    type = "elapsed" if ticket_elapsed?(ticket) and ticket_active
    type = "overdue" if overdue and ticket_active
    type = "customer_responded_overdue" if cust_responded and overdue and ticket_active
    type
  end

  def ticket_elapsed?(ticket)
    !ticket.outbound_email? && ticket.ticket_states.agent_responded_at.blank? && ticket.frDueBy < Time.now && ticket.due_by >= Time.now
  end

  def new_ticket?(ticket,onhold_and_closed_statuses)
    ticket.ticket_states.is_new? && !onhold_and_closed_statuses.include?(ticket.ticket_status.status_id)
  end

  def customer_responded_to_ticket?(ticket)
    ticket.ticket_states.customer_responded?
  end

  def customer_responded_for_outbound?(ticket)
    ticket.ticket_states.customer_responded_for_outbound?
  end

  def ticket_overdue?(ticket,onhold_and_closed_statuses)
    !onhold_and_closed_statuses.include?(ticket.ticket_status.status_id) && ticket.due_by < Time.now 
  end

  def sla_status(ticket,onhold_and_closed_statuses)
    if( ticket.active? )
      unless (onhold_and_closed_statuses.include?(ticket.ticket_status.status_id) or ticket.ticket_status.deleted?)
        if(Time.now > ticket.due_by )
          t('already_overdue',:time_words => distance_of_time_in_words(Time.now, ticket.due_by))
        else
          t('due_in',:time_words => distance_of_time_in_words(Time.now, ticket.due_by))
        end
      else
        " #{h(status_changed_time_value_hash(ticket)[:title])} #{t('for')} 
            #{distance_of_time_in_words(Time.now, ticket.ticket_states.send(status_changed_time_value_hash(ticket)[:method]))} "
      end
 
    else
      if( ticket.ticket_states.resolved_at_dirty < ticket.due_by )
        t('resolved_on_time')
      else
        t('resolved_late')
      end
    end
  end

  def status_changed_time_value_hash (ticket)
    status_name = ticket.status_name
    status = ticket.status
    case status
      when RESOLVED
        return {:title => "#{status_name}", :method => "resolved_at_dirty"}
      when PENDING
        return {:title =>  "#{status_name}", :method => "pending_since"}
      when CLOSED
        return {:title => "#{status_name}", :method => "closed_at_dirty"}
      else
        return {:title => "#{status_name}", :method => "status_updated_at"}
    end
  end
end
