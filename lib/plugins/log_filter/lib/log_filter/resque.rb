class Resque::Job
	def inspect
		obj		= @payload
		@logged_args 	||= obj['args'].map do |arg| 
												arg.is_a?(Hash) ? arg.with_indifferent_access.except(*Constants::FILTER_KEYS) : arg
											end
		"(Job{%s} | %s | %s)" % [ @queue, obj['class'], @logged_args.inspect ]
	end
end