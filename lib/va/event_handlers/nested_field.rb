class Va::EventHandlers::NestedField < Va::EventHandler

	def matches? current_events, evaluate_on
		return false unless current_events[@event.name].present? || (matches_nested_fields? current_events)
		current_value = evaluate_on.flexifield.send(@event.name) if current_events[@event.name].nil?
		from, to = current_events[@event.name] || [current_value, current_value]

    @handler = "Va::Handlers::Text".constantize.new @event, rule
		return false unless ( @handler.event_matches? from, :from ) && ( @handler.event_matches? to, :to )
		return matches_nested_rules? current_events.clone, evaluate_on
	end

	private

		def matches_nested_fields? current_events
			(@rule[:nested_rule]||[]).any? { |n_rule| 	
				current_events[n_rule[:name].to_sym] }
		end
	
		def def_event sub_rule
	    Va::Event.new sub_rule, @account
		end

		def matches_nested_rules? current_events, evaluate_on
			@rule[:nested_rule].all? do |nr|
				matches_single_rule? current_events.clone, evaluate_on, (def_event nr), nr
			end
		end

		def matches_single_rule? current_events, evaluate_on, event, rule
			current_value = evaluate_on.flexifield.send(event.name)
			current_events[event.name] ||= [current_value, current_value]
			return (event.event_matches? current_events, evaluate_on)
		end

end