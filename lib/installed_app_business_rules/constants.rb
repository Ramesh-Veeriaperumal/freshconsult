module InstalledAppBusinessRules::Constants

  USER_CREATE_ACTION = { :user_action => :create }  

  COMPANY_CREATE_ACTION = { :company_action => :create }
  COMPANY_UPDATE_ACTION = { :company_action => :update }
  
  COMPANY_SUBSCRIBE_EVENTS = [:domains]

  FETCH_EVALUATE_ON_ID = { 'User' => :id, 'Company' => :id }

  MAP_CREATE_ACTION = {  'User' => USER_CREATE_ACTION, 
                         'Company' => COMPANY_CREATE_ACTION }

  MAP_UPDATE_ACTION = { 'Company' => COMPANY_UPDATE_ACTION }

  MAP_SUBSCRIBE_EVENT = { 'Company' =>  COMPANY_SUBSCRIBE_EVENTS }

  PERFORMER_ANYONE = '3'

end