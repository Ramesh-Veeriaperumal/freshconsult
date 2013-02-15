class Va::Event

	attr_accessor :account, :name, :from, :to, :value, :rule, :event_handler

	def initialize rule, account
		@account, @name, @from, @to, @value, @rule = account, rule[:name].to_sym, rule[:from], rule[:to], rule[:value], rule
	end

	def event_matches? current_events, evaluate_on
		if @rule[:rule_type].nil?	
			return false if current_events[name].nil?
			init_event_handler
			@event_handler.event_matches? *current_events[name]
		else
			if current_events[name].present? || (matches_nested_fields? current_events)
				init_event_handler 'Va::EventHandlers::NestedField'
				@event_handler.event_matches? current_events, evaluate_on
			end	
		end
	end

	private

		def init_event_handler event_handler_class = nil
			event_handler_class ||=  VAConfig.handler @name.to_sym, @account, :event_handler
			@event_handler = event_handler_class.constantize.new( self, rule, @account )
		end

		def matches_nested_fields? current_events
			(@rule[:nested_rule]||[]).any? { |n_rule| 	current_events[n_rule[:name].to_sym] }
		end

end