module TimeZone
  def self.set_time_zone
    Time.zone = self.find_time_zone
  end

  def self.find_time_zone
    User.current ? User.current.time_zone : (Account.current ? Account.current.time_zone : Time.zone)
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