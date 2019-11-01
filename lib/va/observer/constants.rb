module Va::Observer::Constants

  FETCH_EVALUATE_ON_ID = {  'Helpdesk::Ticket' => :id,
                            'Helpdesk::Note' => :notable_id,
                            'CustomSurvey::SurveyResult' => :surveyable_id,
                            'SurveyResult' => :surveyable_id,
                            'Helpdesk::TimeSheet' => :workable_id }

  FETCH_DOER_ID = { 'Helpdesk::Note' => :user_id,
                    'CustomSurvey::SurveyResult' => :customer_id,
                    'SurveyResult' => :customer_id,
                    'Helpdesk::TimeSheet' => :user_id,
                  }

  TICKET_EVENTS = [ :status, :priority, :ticket_type, :group_id, :responder_id, :due_by, :deleted, :spam,
                    :time_sheet_action, :reply_sent, :note_type, :customer_feedback, :round_robin_assignment,
                    :mail_del_failed_requester, :mail_del_failed_others, :response_due, :resolution_due,
                    :association_type ]

  TICKET_UPDATED = { :ticket_action => :update }
  TICKET_DELETED = { :ticket_action => :delete }
  TICKET_MARKED_SPAM = { :ticket_action => :marked_spam }
  #TICKET_RESTORED = { :ticket_action => :restored }
  #TICKET_UNMARKED_SPAM = { :ticket_action => :unmarked_as_spam }
  TICKET_LINKED = { ticket_action: :linked }

  CHECK_FOR_EVENT_SPECIAL_CASES = [ :deleted, :spam, :association_type ]
  UPDATE_EVENT_SPECIAL_CASES = { 
                          true => { :deleted => TICKET_DELETED, :spam => TICKET_MARKED_SPAM },
                          #false => { :deleted => TICKET_RESTORED, :spam => TICKET_UNMARKED_SPAM }
                          4 => { association_type: TICKET_LINKED }
                        }
end
