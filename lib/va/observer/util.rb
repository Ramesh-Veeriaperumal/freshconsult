module Va::Observer::Util

	include Va::Observer::Constants
	include Va::Util
	include Redis::RedisKeys
	include Redis::OthersRedis  

	private

		def user_present?
			observer_condition = @model_changes && (User.current || survey_result?) && 
																														!zendesk_import? && !freshdesk_webhook?
			Rails.logger.debug "INSIDE user_present? for object: #{self.inspect} observer_condition: #{observer_condition}"
			return observer_condition
		end

		def filter_observer_events
			observer_changes = @model_changes.inject({}) do |filtered, (change_key, change_value)| 
																						filter_event filtered, change_key, change_value  end
			send_events(observer_changes) unless observer_changes.blank? 
		end

		def filter_event filtered, change_key, change_value
			( TICKET_EVENTS.include?( change_key ) ||
				Account.current.event_flexifields_with_ticket_fields_from_cache.
																					map(&:flexifield_name).map(&:to_sym).include?(change_key)
					) ? filtered.merge!({change_key => change_value}) : filtered
		end

		def send_events observer_changes
			observer_changes.merge! ticket_event observer_changes
			doer_id = (self.class == Helpdesk::Ticket) ? User.current.id : self.send(FETCH_DOER_ID[self.class.name])
			evaluate_on_id = self.send FETCH_EVALUATE_ON_ID[self.class.name]
			Tickets::ObserverWorker.perform_async({
				:doer_id => doer_id,
				:ticket_id => evaluate_on_id,
				:current_events => observer_changes })
		end

		def ticket_event current_events
			CHECK_FOR_EVENT_SPECIAL_CASES.each do |key|
				unless current_events[key].nil?
					bool = current_events[key][1]
					return UPDATE_EVENT_SPECIAL_CASES[bool][key] if bool
				end
			end 
			return TICKET_UPDATED
		end

		def survey_result?
			self.is_a?(SurveyResult) || self.is_a?(CustomSurvey::SurveyResult)
		end
		
end