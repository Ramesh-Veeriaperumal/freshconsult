module Va::ObserverUtil

	private

		TICKET_EVENTS = [ :status, :priority, :ticket_type, :group_id, :responder_id, :due_by,
			:time_sheet_action, :deleted, :spam, :reply_sent, :note_type, Helpdesk::SchemaLessTicket.survey_result_column ]

		TICKET_UPDATED = { :ticket_update => :updated }
		TICKET_DELETED = { :ticket_update => :deleted }
		#TICKET_RESTORED = { :ticket_update => :restored }
		TICKET_MARKED_SPAM = { :ticket_update => :marked_as_spam }
		#TICKET_UNMARKED_SPAM = { :ticket_update => :unmarked_as_spam }

		MERGE = { 
							true => { :deleted => TICKET_DELETED, :spam => TICKET_MARKED_SPAM },
						  #false => { :deleted => TICKET_RESTORED, :spam => TICKET_UNMARKED_SPAM }
						}
		
		CHECK = [:deleted, :spam]
		
		EVALUATE_ON = { 
										'Helpdesk::Note' => 'notable',
										'Helpdesk::TimeSheet' => 'ticket',
										'SurveyResult' => 'surveyable'
									}

		def user_present?
			p (User.current && @model_changes)
			User.current && @model_changes
	  end

	  def filter_observer_events
	  	@evaluate_on = self.class == Helpdesk::Ticket ? self : self.send(EVALUATE_ON[self.class.name])
	  	p "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
	  	p Helpdesk::Ticket.find @evaluate_on.id
	  	p @model_changes
	    @model_changes = @model_changes.inject({}) do |filtered, (change_key, change_value)| 
	    																			filter_event filtered, change_key, change_value  end
			send_events unless @model_changes.blank?
	  end

	  def filter_event filtered, change_key, change_value
	  	(	TICKET_EVENTS.include?( change_key ) ||
	  		@evaluate_on.account.flexifield_def_entries.event_fields.
	  																			map(&:flexifield_name).map(&:to_sym).include?(change_key)
	  			) ? filtered.merge({change_key => change_value}) : filtered
	  end

	  def send_events
	  	p "Enqueuing"
	  	p @model_changes
	  	@model_changes.merge! ticket_event @model_changes
	    Resque.enqueue Workers::Observer, @evaluate_on.id, User.current.id, @model_changes
	    #Workers::Observer.perform @evaluate_on.id, User.current.id, @model_changes
	    # Delayed::Job.enqueue Workers::Observer.new(@evaluate_on.id, User.current.id, @model_changes)
	  end

	  def ticket_event current_events
			CHECK.each do |key|
				unless current_events[key].nil?
					bool = current_events[key][1]
					return MERGE[bool][key] if bool
				end
			end 
			return TICKET_UPDATED
		end
		
end

