module SupportHelper
	include ActionView::Helpers::TagHelper
	include ActionView::Helpers::DateHelper
	# Forum based helpers 
	# Have to move these into their respective pages
	def bold( content )
		content_tag :strong, content
	end

	def day_and_time( date_time )
		date_time.to_s(:long_day_with_time)
	end

	# Applicaiton link helpers
	# move link_helpers into this area
	
end
