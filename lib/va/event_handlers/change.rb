class Va::EventHandlers::Change < Va::EventHandler

	def event_matches? *change
		change.present?
	end

end
