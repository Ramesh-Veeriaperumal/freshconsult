module Helpdesk::Ticketfields::TicketStatus
  
  OPEN = 2 # Open Status
  PENDING = 3 # Pending Status
  RESOLVED = 4 # Resolved Status
  CLOSED = 5 # Closed Status

  DEFAULT_STATUSES = [OPEN, PENDING, RESOLVED, CLOSED]

  # In order to save modified records through autosave we need to manipulate the loaded ticket_statuses array itself in the self
  def update_ticket_status(attr)
    attr.symbolize_keys!
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

    attr.delete(:status_id)
    unless t_s.nil?
      t_s.attributes = attr
      validate_default_statuses(t_s)
      ticket_statuses[index] = t_s
    else
      t_s = ticket_statuses.build() 
      t_s.attributes = attr
      t_s.account = account
    end
  end

  private

    def validate_default_statuses(t_s)
      if(DEFAULT_STATUSES.include?(t_s.status_id))
        t_s.deleted = false
        t_s.is_default = true
        if(t_s.status_id == OPEN)
          t_s.stop_sla_timer = false
        elsif([RESOLVED,CLOSED].include?(t_s.status_id))
          t_s.stop_sla_timer = true  
        end
      end  
    end
  
end