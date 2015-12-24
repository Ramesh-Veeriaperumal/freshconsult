module HelpdeskV2ReportsHelper

	include Reports::CommonHelperMethods
	
	DEFAULT_DATE_RANGE = 29 

	def default_date_range lag
		current_account_time = Time.now.utc.in_time_zone(current_account.time_zone)
		return [current_account_time - (DEFAULT_DATE_RANGE + lag).days, current_account_time - lag.days]
	end

end