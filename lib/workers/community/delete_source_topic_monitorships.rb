class Workers::Community::DeleteSourceTopicMonitorships

	def perform(args)
		args[:source_monitorship_ids].each do |id|
			Monitorship.find(id).destroy
		end
	end

end