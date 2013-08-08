class Va::EventHandlers::Change < Va::EventHandler

	private
	
		def event_matches? *change
			change.present?
		end

end
