class Va::EventHandlers::Update < Va::EventHandler

	def event_matches? from, to
		init_handler
		( @handler.event_matches? from, :from ) && ( @handler.event_matches? to, :to )
	end

end