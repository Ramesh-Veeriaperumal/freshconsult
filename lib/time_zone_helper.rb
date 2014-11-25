module TimeZoneHelper
	
	def set_time_zone(user)
    Time.zone =  user.time_zone || (Account.current ? Account.current.time_zone : Time.zone)
  end

end