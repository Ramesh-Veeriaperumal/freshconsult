class Va::EventHandlers::Update < Va::EventHandler

	private

		def event_matches? from, to
			( @handler.event_matches? from, :from ) && ( @handler.event_matches? to, :to )
		end

end