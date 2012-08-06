module SupportHelper
	include ActionView::Helpers::TagHelper
	include ActionView::Helpers::DateHelper
	# Forum based helpers 
	# Have to move these into their respective pages
	def bold( content )
		content_tag :strong, content
	end

	def long_day( date_time )
		date_time.to_s(:long_day)
	end
end
