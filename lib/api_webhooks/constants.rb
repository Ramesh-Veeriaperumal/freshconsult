module ApiWebhooks::Constants

  USER_CREATE_ACTION = { :user_action => :create }  
  USER_UPDATE_ACTION = { :user_action => :update }
  USER_SUBSCRIBE_EVENTS = [ :name, :email, :customer_id, :job_title, :phone, :mobile, 
                            :description, :helpdesk_agent, :address]

  TICKET_SUBSCRIBE_EVENTS = [ :status, :priority, :ticket_type, :group_id, :responder_id, :due_by,
                              :deleted]

  TICKET_CREATE_ACTION = { :ticket_action => :create }   
  TICKET_UPDATE_ACTION = { :ticket_action => :update }	
  NOTE_CREATE_ACTION = { :note_action => :create } 

  FETCH_EVALUATE_ON_ID = { 'Helpdesk::Ticket' => :id, 'Helpdesk::Note' => :id, 'User' => :id }

  MAP_CREATE_ACTION = { 'Helpdesk::Ticket' => TICKET_CREATE_ACTION, 
                        'Helpdesk::Note' => NOTE_CREATE_ACTION, 'User' => USER_CREATE_ACTION }

  MAP_UPDATE_ACTION = { 'Helpdesk::Ticket' => TICKET_UPDATE_ACTION, 'User' => USER_UPDATE_ACTION }

  MAP_SUBSCRIBE_EVENT = { 'Helpdesk::Ticket' => TICKET_SUBSCRIBE_EVENTS, 
                          'User' => USER_SUBSCRIBE_EVENTS }

  PERFORMER_ANYONE = '3'

  WHITELISTED_DOMAIN = ['zapier.com', 'www.timecamp.com', 'app.hotline.io', 'app.konotor.com']

end