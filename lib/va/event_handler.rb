class Va::EventHandler

	attr_accessor :account, :event, :rule, :handler, :act_on

	def initialize event, rule, account
		@event, @rule, @account = event, rule, account
		handler_class = VAConfig.handler @event.name.to_sym, @account
    @handler = handler_class.constantize.new @event, rule
	end

	def matches? current_events, evaluate_on
		@act_on = evaluate_on
		return false if current_events[@event.name].nil?
		event_matches? *current_events[@event.name]
	end

end
