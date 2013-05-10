module Va::Observer::Constants

	FETCH_EVALUATE_ON = { 'Helpdesk::Note' => 'notable',
												'SurveyResult' => 'surveyable',
												'Helpdesk::TimeSheet' => 'workable'	}

	TICKET_EVENTS = [ :status, :priority, :ticket_type, :group_id, :responder_id, :due_by,
										:time_sheet_action, :deleted, :spam, :reply_sent, :note_type,
										Helpdesk::SchemaLessTicket.survey_result_column ]

	TICKET_UPDATED = { :ticket_update => :updated }
	TICKET_DELETED = { :ticket_update => :deleted }
	TICKET_MARKED_SPAM = { :ticket_update => :marked_as_spam }
	#TICKET_RESTORED = { :ticket_update => :restored }
	#TICKET_UNMARKED_SPAM = { :ticket_update => :unmarked_as_spam }

	CHECK_FOR_EVENT_SPECIAL_CASES = [ :deleted, :spam ]
	UPDATE_EVENT_SPECIAL_CASES = { 
													true => { :deleted => TICKET_DELETED, :spam => TICKET_MARKED_SPAM },
												  #false => { :deleted => TICKET_RESTORED, :spam => TICKET_UNMARKED_SPAM }
												}		

end