class Va::EventHandlers::Value < Va::EventHandler

	def event_matches? *value
		init_handler
		@handler.event_matches? value.last, :value
	end

end
