class Va::EventHandlers::Value < Va::EventHandler

	def event_matches? *value
		value = value.last
		init_handler
		@handler.event_matches? value, :value
	end

end
