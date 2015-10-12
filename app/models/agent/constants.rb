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

  EXPORT_FIELDS = [
    {:label => "export_data.agents.fields.name", :value => "agent_name", :selected => true},
    {:label => "export_data.agents.fields.email",   :value => "agent_email",    :selected => true},
    {:label => "export_data.agents.fields.agent_type", :value => "agent_type", :selected => false},
    {:label => "export_data.agents.fields.ticket_scope",    :value => "ticket_scope", :selected => true},
    {:label => "export_data.agents.fields.roles", :value => "agent_roles", :selected => false},
    {:label => "export_data.agents.fields.groups", :value => "groups", :selected => false},
    {:label => "export_data.agents.fields.phone", :value => "agent_phone", :selected => false},
    {:label => "export_data.agents.fields.mobile", :value => "agent_mobile", :selected => false},
    {:label => "export_data.agents.fields.language", :value => "agent_language", :selected => false},
    {:label => "export_data.agents.fields.time_zone", :value => "agent_time_zone", :selected => false}
  ]

  EXPORT_FIELD_VALUES = EXPORT_FIELDS.map { |field| field[:value] }
  
end