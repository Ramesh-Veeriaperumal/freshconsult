module ApiWebhooks::Methods
	
	include ApiWebhooks::Constants
	include Va::Util

	def allow_api_webhook?
		api_webhook_condition = !zendesk_import? && !freshdesk_webhook?
		return api_webhook_condition
	end

	def subscribe_event_create 
		event_changes = MAP_CREATE_ACTION[self.class.name]
		send_subscribe_events(event_changes) unless event_changes.blank?
	end

	def subscribe_event_update
		event_changes = @model_changes.inject({}) do |filtered, (change_key, change_value)| 
																		filter_subscribe_event filtered, change_key, change_value  end

		unless event_changes.blank?																	
			event_changes.merge! MAP_UPDATE_ACTION[self.class.name] 
			send_subscribe_events event_changes 
		end
	end

	def filter_subscribe_event filtered, change_key, change_value
		( MAP_SUBSCRIBE_EVENT[self.class.name].include?( change_key ) ||
			Account.current.event_flexifields_with_ticket_fields_from_cache.
																				map(&:flexifield_name).map(&:to_sym).include?(change_key)
				) ? filtered.merge!({change_key => change_value}) : filtered
	end

	def map_class class_name
    attr_map = {"Helpdesk::Ticket" => :tickets, "User" => :users, "Helpdesk::Note" => :notes}
    attr_map[class_name]
  end

	def send_subscribe_events event_changes
		evaluate_on_id = self.send FETCH_EVALUATE_ON_ID[self.class.name]

		Resque.enqueue(Workers::Subscriber,
						{ :event_id => evaluate_on_id, :current_events => event_changes, 
							:association => map_class(self.class.name)})
					
	end
end