module TimeZone
  def self.set_time_zone
    begin
      Time.zone = self.find_time_zone
    rescue ArgumentError => e
      NewRelic::Agent.notice_error(e)
      Rails.logger.debug "Timezone thread exception:: #{Thread.current}"
    end
  end

  def self.find_time_zone
    newrelic_begin_rescue_block {
      User.current ? User.current.time_zone : (Account.current ? Account.current.time_zone : Time.zone)
    }
  end

  # Adding this method to fetch timezone of format "Area/location" Like: "Asia/Kolkata" instead "Kolkata" 
  def self.fetch_tzinfoname
    newrelic_begin_rescue_block {
      timezone_value =  get_timezonemap(User.current.time_zone) if User.current
      timezone_value ? timezone_value.tzinfo.name : get_timezonemap(Account.current.time_zone).tzinfo.name
    }
  end

  def self.get_timezonemap(time_zone)
    @time_zone_mapping ||= ActiveSupport::TimeZone.zones_map
    @time_zone_mapping[time_zone]
  end

  def self.newrelic_begin_rescue_block(&block) 
    begin
      block.call
    rescue ArgumentError => e
      NewRelic::Agent.notice_error(e)
      Rails.logger.debug "Timezone thread exception:: #{Thread.current}"
      # we have problem with Kyev. In rails 2.3.18 Kyev , but in Rails 3.2.18 its corrected to Kyiv
      # https://rails.lighthouseapp.com/projects/8994/tickets/2613-fix-spelling-of-kyiv-timezone
      if e.message.include?("Invalid Timezone: Kyev")
        "Kyiv" 
      elsif Account.current
         #incase the timezone of the user is incorrect, defaulting to account's timezone
         #http://bugs.freshdesk.com/helpdesk/tickets/9771
        Rails.logger.debug "Timezone Error:: #{Account.current}"
        Account.current.time_zone 
      else
        raise e
      end
    end
  end
end