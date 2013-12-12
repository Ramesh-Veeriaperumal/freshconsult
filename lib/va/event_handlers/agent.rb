class Va::EventHandlers::Agent < Va::EventHandler

	private

		def event_matches? from, to
			if rule.keys.include?(:from)
				event_handler = 'Va::EventHandlers::Update'.constantize.new event, rule, account
			else
				event_handler = 'Va::EventHandlers::Change'.constantize.new event, rule, account
			end
			event_handler.matches?( {:responder_id => [from,to]}, act_on )
		end

end