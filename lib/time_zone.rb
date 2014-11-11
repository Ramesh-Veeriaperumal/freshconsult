module TimeZone
  def self.set_time_zone
    Time.zone = User.current ? User.current.time_zone : (Account.current ? Account.current.time_zone : Time.zone)
  rescue ArgumentError => e
    # we have problem with Kyev. In rails 2.3.18 Kyev , but in Rails 3.2.18 its corrected to Kyiv
    # https://rails.lighthouseapp.com/projects/8994/tickets/2613-fix-spelling-of-kyiv-timezone
    if e.message.include?("Invalid Timezone: Kyev")
      Time.zone = "Kyiv" 
    else
      raise e
    end
  end
end