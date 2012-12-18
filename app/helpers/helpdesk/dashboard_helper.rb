module Helpdesk::DashboardHelper
	def find_activity_url(activity)
		activity_data = activity.activity_data
	 	(activity_data.empty? || activity_data[:path].nil? ) ? activity.notable : activity_data[:path]
	end
end
