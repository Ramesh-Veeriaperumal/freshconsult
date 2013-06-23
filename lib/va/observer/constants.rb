module Va::Observer::Constants

	FETCH_EVALUATE_ON_ID = {	'Helpdesk::Ticket' => :id,
														'Helpdesk::Note' => :notable_id,
														'SurveyResult' => :surveyable_id,
														'Helpdesk::TimeSheet' => :workable_id }
	FETCH_DOER_ID = { 	'Helpdesk::Note' => :user_id,
											'SurveyResult' => :customer_id,
											'Helpdesk::TimeSheet' => :user_id }

	TICKET_EVENTS = [ :status, :priority, :ticket_type, :group_id, :responder_id, :due_by,
										:time_sheet_action, :deleted, :spam, :reply_sent, :note_type,
										:customer_feedback ]

	TICKET_UPDATED = { :ticket_action => :update }
	TICKET_DELETED = { :ticket_action => :delete }
	TICKET_MARKED_SPAM = { :ticket_action => :marked_spam }
	#TICKET_RESTORED = { :ticket_action => :restored }
	#TICKET_UNMARKED_SPAM = { :ticket_action => :unmarked_as_spam }

	CHECK_FOR_EVENT_SPECIAL_CASES = [ :deleted, :spam ]
	UPDATE_EVENT_SPECIAL_CASES = { 
													true => { :deleted => TICKET_DELETED, :spam => TICKET_MARKED_SPAM },
												  #false => { :deleted => TICKET_RESTORED, :spam => TICKET_UNMARKED_SPAM }
												}		

end