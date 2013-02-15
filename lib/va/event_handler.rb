class Va::EventHandler

	attr_accessor :account, :event, :rule, :handler

	def initialize event, rule, account
		@event, @rule, @account = event, rule, account
	end

	private
	
		def init_handler 
			handler_class = VAConfig.handler @event.name.to_sym, @account, :event_rule_handler
	    @handler = handler_class.constantize.new( @event, rule )
		end
	
end
