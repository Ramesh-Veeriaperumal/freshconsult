

class Wf::Containers::Time < Wf::FilterContainer

  def self.operators
    [ :is_greater_than ]
  end

  def validate
    return "Value must be provided" if value.blank?
    return "Value must be a valid date/time (2008-01-01 14:30:00)" if time == nil
  end

  def time
    begin
      Time.zone.now.ago(value.to_i.minutes)
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      nil
    end
  end

  def sql_condition
    case value
      when "today" then
        return [" `helpdesk_tickets`.created_at > '#{Time.zone.now.beginning_of_day}' "]
      when "yesterday" then
        return [%( `helpdesk_tickets`.created_at > '#{Time.zone.now.yesterday.beginning_of_day}' and
          `helpdesk_tickets`.created_at < '#{Time.zone.now.beginning_of_day}' )]
      when "week" then
        return [" `helpdesk_tickets`.created_at > '#{Time.zone.now.beginning_of_week}' "]
      when "month" then
        return [" `helpdesk_tickets`.created_at > '#{Time.zone.now.beginning_of_month}' "]
      when "two_months" then
        return [" `helpdesk_tickets`.created_at > '#{Time.zone.now.beginning_of_day.ago(2.months)}' "]
      when "six_months" then
        return [" `helpdesk_tickets`.created_at > '#{Time.zone.now.beginning_of_day.ago(6.months)}' "]
      else
        return [" `helpdesk_tickets`.created_at > ? ", time]
    end 
  end

end
