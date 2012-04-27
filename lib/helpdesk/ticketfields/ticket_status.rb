module Helpdesk::Ticketfields::TicketStatus
  
  OPEN = 2 # Open Status
  PENDING = 3 # Pending Status
  RESOLVED = 4 # Resolved Status
  CLOSED = 5 # Closed Status

  # In order to save modified records through autosave we need to manipulate the loaded ticket_statuses array itself in the self
  def update_ticket_status(attr)
    t_s = nil
    index = -1
    ticket_statuses.each do |st|
      index = index+1
      if(st.status_id == attr[:status_id])
        t_s = st
        break
      elsif(st.name == attr[:name] and st.deleted?)
        t_s = st
        t_s.deleted = false # restore the deleted status if the user adds the status with the same name
        break
      end
    end

    unless t_s.nil?
      t_s.attributes = attr
      ticket_statuses[index] = t_s
    else
      t_s = ticket_statuses.build() 
      t_s.attributes = attr
      t_s.account = account
    end
  end
  
  def delete_ticket_status(id)
    ticket_status = Account.current.ticket_status_values.find_by_status_id(id)
    ticket_status.deleted = true
    ticket_status.save
  end

end