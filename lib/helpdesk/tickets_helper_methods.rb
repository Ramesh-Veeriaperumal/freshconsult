module Helpdesk::TicketsHelperMethods

  include Helpdesk::Ticketfields::TicketStatus
  
  def subject_style(ticket,onhold_and_closed_statuses)
    type = "customer_responded" if ticket.ticket_states.customer_responded? && ticket.active?
    type = "new" if ticket.ticket_states.is_new? && !onhold_and_closed_statuses.include?(ticket.ticket_status.status_id)
    type = "elapsed" if ticket.ticket_states.agent_responded_at.blank? && ticket.frDueBy < Time.now && ticket.due_by >= Time.now && ticket.active?
    type = "overdue" if !onhold_and_closed_statuses.include?(ticket.ticket_status.status_id) && ticket.due_by < Time.now && ticket.active? 
    type
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