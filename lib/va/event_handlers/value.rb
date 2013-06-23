class Va::EventHandlers::Value < Va::EventHandler

	private
	
		def event_matches? *value
			@handler.event_matches? value.last, :value
		end

end
