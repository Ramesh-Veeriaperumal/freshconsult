module Support::SupportHelper
	# Forum based helpers 
	# Have to move these into their respective pages
	def topic_filters
		[[(params[:stamp_type].blank? && params[:order].blank?) ],
		[(!params[:order].blank? && params[:order] == 'created_at desc')],
		[(!params[:order].blank? && params[:order] == 'replied_at desc')]]
	end
end
