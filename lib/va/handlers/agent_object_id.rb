class Va::Handlers::AgentObjectId < Va::Handlers::ObjectId

	# Hack for Agent updated event to avoid migration
	def is(evaluate_on_value)
		!rule_hash.keys.include?(value_key) || (evaluate_on_value == proper_value)
	end

end