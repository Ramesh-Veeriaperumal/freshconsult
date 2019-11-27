module BusinessHoursCalculation
  
  def action_occured_in_bhrs?(action_time, group)
    business_calendar_config = Group.default_business_calendar(group)
    in_bhrs = Time.working_hours?(action_time,business_calendar_config)
  end
  
  def calculate_time_in_bhrs(previous_action_time, action_time, group)
    business_calendar_config = Group.default_business_calendar(group)
    time_in_bhrs = Time.zone.parse(previous_action_time.to_s).
                         business_time_until(Time.zone.parse(action_time.to_s),business_calendar_config)

  end

  def set_updated_time(ticket)
    ticket.ticket_states.resolution_time_updated_at = time_zone_now
    Rails.logger.debug "SLA :::: Account id #{ticket.account_id} :: #{ticket.new_record? ? 'New' : ticket.id} ticket :: Updating resolution time :: resolution_time_updated_at :: #{ticket.ticket_states.resolution_time_updated_at}"
    if ticket.last_customer_note_id.present?
      ticket.nr_updated_at = time_zone_now
      Rails.logger.debug "SLA :::: Account id #{ticket.account_id} :: #{ticket.new_record? ? 'New' : ticket.id} ticket :: Updating next response time :: nr_updated_at :: #{ticket.nr_updated_at}"
    end

  end
end