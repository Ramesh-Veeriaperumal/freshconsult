class Va::Event

	attr_accessor :account, :name, :rule, :event_handler

	def initialize rule, account
		@name, @rule, @account = rule[:name].to_sym, rule, account
		event_handler_class = VAConfig.event_handler @name.to_sym, @account
		@event_handler = event_handler_class.constantize.new( self, @rule, @account )
	end

	def event_matches? current_events, evaluate_on
		@event_handler.matches? current_events, evaluate_on
	end

end