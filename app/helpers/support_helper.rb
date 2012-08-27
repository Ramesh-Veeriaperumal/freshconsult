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

	# rendering partial if its corresponding db_file is not available
	def portal_render( local_file, db_file = "" )
		# render_to_string :partial => local_file, :locals => { :dynamic_template => db_file }
	end
	
end
