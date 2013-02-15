module Va::ObserverUtil

	private

		TICKET_EVENTS = [ :status, :priority, :ticket_type, :group_id, :responder_id, :due_by,
																				 :survey_result, :time_sheet, :deleted, :spam, :reply, :note, :int_tc01 ]

		TICKET_UPDATED = { :ticket => :updated }
		TICKET_DELETED = { :ticket => :deleted }
		TICKET_RESTORED = { :ticket => :restored }
		TICKET_MARKED_SPAM = { :ticket => :marked_as_spam }
		TICKET_UNMARKED_SPAM = { :ticket => :unmarked_as_spam }

		MERGE = { 
							true => { :deleted => TICKET_DELETED, :spam => TICKET_MARKED_SPAM },
						  false => { :deleted => TICKET_RESTORED, :spam => TICKET_UNMARKED_SPAM }
						}
		
		CHECK = [:deleted, :spam]
		
		EVALUATE_ON = { 
										'Helpdesk::Ticket' => 'ticket',
										'Helpdesk::Note' => 'notable',
										'Helpdesk::TimeSheet' => 'ticket',
										'SurveyResult' => 'surveyable'
									}

		def current_user?
			User.current && @observer_changes
	  end

	  def filter_observer_events
	  	@evaluate_on = self.send( EVALUATE_ON[ self.class.name ] )
	    @observer_changes = @observer_changes.inject({}) { |z,k| filter_event z,k }
			send_events unless @observer_changes.blank?
	  end

	  def filter_event z, k
	  	( 
	  		TICKET_EVENTS.include?( k[0] ) ||
	  			@evaluate_on.account.flexifield_def_entries.event_fields.map(&:flexifield_name).include?( k[0] ) 
	  				) ? z.merge({k[0] => k[1]}) : z 
	  end

	  def send_events
	  	(@observer_changes.merge! ticket_event @observer_changes ).symbolize_keys!
	    trigger_observer( User.current, @observer_changes, @evaluate_on, self.class.name)
	    # send_later(:trigger_observer, User.current, @observer_changes, @evaluate_on , self.class.name) unless @observer_changes.blank?
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

		def trigger_observer current_user, current_events, evaluate_on, where 
			p evaluate_on, current_events
			evaluate_on.account.observer_rules.each do |vr|
				p vr.id, vr.name
				vr.check_events current_user, evaluate_on, current_events
				p "Changes in Trigger observer"
	      p evaluate_on.changes
	    end
	    p evaluate_on.changes
	    p evaluate_on
	    evaluate_on.save unless evaluate_on.changes.blank?
		end

end

