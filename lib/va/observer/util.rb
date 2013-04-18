module Va::Observer::Util

	include Va::Observer::Constants

	private

		def user_present?
			p "Obz"
	  	p @model_changes
			User.current && @model_changes && !zendesk_import?
	  end

	  def zendesk_import?
      Thread.current["zenimport_#{account_id}"]
    end

	  def filter_observer_events
	  	@evaluate_on = (self.class == Helpdesk::Ticket) ? self : 
	  																									self.send(FETCH_EVALUATE_ON[self.class.name])
	    @observer_changes = @model_changes.inject({}) do |filtered, (change_key, change_value)| 
	    																			filter_events filtered, change_key, change_value  end
			send_events unless @observer_changes.blank? 
	  end

	  def filter_events filtered, change_key, change_value
	  	(	TICKET_EVENTS.include?( change_key ) ||
	  		Account.current.event_flexifields_with_ticket_fields_from_cache.
	  																			map(&:flexifield_name).map(&:to_sym).include?(change_key)
	  			) ? filtered.merge!({change_key => change_value}) : filtered
	  end

	  def send_events
	  	@observer_changes.merge! ticket_event @observer_changes
	  	p "Enqueuing"
	    Resque.enqueue(Workers::Observer,
	     { :ticket_id => @evaluate_on.id, :current_events => @observer_changes })
	    #Workers::Observer.perform @evaluate_on.id, User.current.id, @observer_changes
	    #Delayed::Job.enqueue Workers::Observer.new(@evaluate_on.id, User.current.id, @observer_changes)
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
		
end