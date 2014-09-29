class Agent < ActiveRecord::Base

  API_OPTIONS = { 
    :except => [:account_id,:google_viewer_id],
    :include => { 
      :user =>{ 
        :only => [:id,:name,:email,:created_at,:updated_at,:job_title, :active,
                  :phone,:mobile,:twitter_id, :description,:time_zone,:deleted,
                  :helpdesk_agent,:fb_profile_id,:external_id,:language,:address],
        :methods => [] #User API_OPTIONS method keys are getting included if methods is not defined here.
      }
    }
  }

  TICKET_PERMISSION = [
    [ :all_tickets, 1 ], 
    [ :group_tickets,  2 ], 
    [ :assigned_tickets, 3 ]
  ]
 
  PERMISSION_TOKENS_BY_KEY = Hash[*TICKET_PERMISSION.map { |i| [i[1], i[0]] }.flatten]
  PERMISSION_KEYS_BY_TOKEN = Hash[*TICKET_PERMISSION.map { |i| [i[0], i[1]] }.flatten]
  
end