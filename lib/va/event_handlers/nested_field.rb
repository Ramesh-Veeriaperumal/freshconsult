class Va::EventHandlers::NestedField < Va::EventHandler

	def event_matches? current_events, evaluate_on
		@event.rule[:rule_type] = nil
		return false unless matches? current_events.clone, evaluate_on, @event, rule
		return matches_nested_rule? current_events, evaluate_on
	end

	private
	
		def def_event sub_rule
	    Va::Event.new sub_rule, @account
		end

		def matches_nested_rule? current_events, evaluate_on
			@rule[:nested_rule].all? do |nr|
				matches? current_events.clone, evaluate_on, (def_event nr), nr
			end
		end

		def matches? current_events, evaluate_on, event, rule
			current_value = evaluate_on.flexifield.send(event.name)
			current_events[event.name] ||= [current_value, current_value]
			return (event.event_matches? current_events, evaluate_on)
		end

end