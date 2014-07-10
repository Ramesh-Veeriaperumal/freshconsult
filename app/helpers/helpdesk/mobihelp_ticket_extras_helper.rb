module Helpdesk::MobihelpTicketExtrasHelper
  
  def convert_rfc3339_to_account_timezone(time)
    formated_date(Time.parse(DateTime.rfc3339(time).to_s).utc.in_time_zone(current_account.time_zone))
  end
end