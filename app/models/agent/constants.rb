class Agent < ActiveRecord::Base

  API_OPTIONS = { 
    :except => [:account_id,:google_viewer_id],
    :include => { 
      :user =>{ 
        :only => [:id,:name,:email,:created_at,:updated_at,:job_title, :active,
                  :phone,:mobile,:twitter_id, :description,:time_zone,:deleted,
                  :helpdesk_agent,:fb_profile_id,:external_id,:language,:address, :unique_external_id],
        :methods => [] #User API_OPTIONS method keys are getting included if methods is not defined here.
      }
    }
  }

  TICKET_PERMISSION = [
    [ :all_tickets, 1, I18n.t("agent.global")], 
    [ :group_tickets,  2, I18n.t("agent.group_access")], 
    [ :assigned_tickets, 3, I18n.t("agent.individual")]
  ]

  FIELD_AGENT_TICKET_PERMISSION = [
    [ :group_tickets,  2, I18n.t("agent.group_access")], 
    [ :assigned_tickets, 3, I18n.t("agent.individual")]
  ].freeze

  AGENT_TYPES = [
    [:support_agent, 1],
    [:field_agent, 2],
    [:collaborator, 3]
  ].freeze

  AGENT_LOGIN_LOGOUT_ACTIONS = [
    [true, :logged_in],
    [true, :logged_out]
  ].freeze

  AGENT_LOGIN_LOGOUT_ACTIONS = [
    [true, :logged_in],
    [true, :logged_out]
  ].freeze 
  PERMISSION_TOKENS_BY_KEY = Hash[*TICKET_PERMISSION.map { |i| [i[1], i[0]] }.flatten]
  PERMISSIONS_TOKEN_FOR_FIELD_AGENT = Hash[*FIELD_AGENT_TICKET_PERMISSION.map { |i| [i[1], i[0]] }.flatten]
  PERMISSION_KEYS_BY_TOKEN = Hash[*TICKET_PERMISSION.map { |i| [i[0], i[1]] }.flatten]
  PERMISSION_KEYS_OPTIONS = Hash[*TICKET_PERMISSION.map { |i| [i[1], i[2]] }.flatten]
  PERMISSION_KEYS_FOR_AGENT_TYPES = Hash[*AGENT_TYPES.map { |i| [i[1], i[0]] }.flatten]

  EXPORT_FIELDS = [
    {:label => "export_data.agents.fields.name",         :value => "agent_name",      :selected => true,  :feature => nil,                                 :association => :user               },
    {:label => "export_data.agents.fields.email",        :value => "agent_email",     :selected => true,  :feature => nil,                                 :association => :user               },
    {:label => "export_data.agents.fields.agent_type",   :value => "agent_type",      :selected => false, :feature => nil,                                 :association => nil                 },
    {:label => "export_data.agents.fields.ticket_scope", :value => "ticket_scope",    :selected => true,  :feature => nil,                                 :association => nil                 },
    {:label => "export_data.agents.fields.roles",        :value => "agent_roles",     :selected => false, :feature => nil,                                 :association => {:user => :roles}   },
    {:label => "export_data.agents.fields.groups",       :value => "groups",          :selected => false, :feature => nil,                                 :association => :agent_groups       },
    {:label => "export_data.agents.fields.phone",        :value => "agent_phone",     :selected => false, :feature => nil,                                 :association => :user               },
    {:label => "export_data.agents.fields.mobile",       :value => "agent_mobile",    :selected => false, :feature => nil,                                 :association => :user               },
    {:label => "export_data.agents.fields.language",     :value => "agent_language",  :selected => false, :feature => nil,                                 :association => :user               },
    {:label => "export_data.agents.fields.time_zone",    :value => "agent_time_zone", :selected => false, :feature => nil,                                 :association => :user               },
    {:label => "export_data.agents.fields.last_seen",    :value => "last_active_at",  :selected => false, :feature => nil,                                 :association => nil                 },
    {:label => "export_data.agents.fields.skills",       :value => "skills_name",     :selected => false, :feature => "skill_based_round_robin_enabled?",  :association => {:user => :skills}  }
  ]

  EXPORT_FIELD_VALUES = EXPORT_FIELDS.map { |field| field[:value] }

  SKILL_EXPORT_FIELDS = {"Name"=>"agent_name", "Email"=>"agent_email",
                          "Groups"=>"groups", "Skills"=>"skills_name"}

  SKILL_IMPORT_FIELDS = ["Email", "Skills"]
 
  AGENTS_THRESHOLD_FOR_AUTOCOMPLETE_ES = 25

  AGENT_ASSOCIATIONS = Hash[*EXPORT_FIELDS.map { |i| [i[:value], i[:association]] }.flatten ].delete_if { |key, value| value.blank? }

  def self.allowed_export_fields
    allowed_fields = []
    EXPORT_FIELDS.each do |i|
          ( allowed_fields << i ) if Export::ExportFields.allow_field? i[:feature]
      end
    allowed_fields
  end
  
  SUPPORT_AGENT_TYPE = 1
  SUPPORT_AGENT = 'support_agent'
  FIELD_AGENT = 'field_agent'
  DELETED_AGENT = 'deleted'
  COLLABORATOR = 'collaborator'.freeze
  
  AGENT_GROUP_TYPE_MAPPING = GroupConstants::GROUPS_AGENTS_MAPPING.invert
  ALLOWED_PERMISSION_FOR_FIELD_AGENT = [PERMISSION_KEYS_BY_TOKEN[:assigned_tickets], PERMISSION_KEYS_BY_TOKEN[:group_tickets]].freeze

  UN_AVAILABLE = ['unavailable'].freeze

  OUT_OF_OFFICE = ['out_of_office', 'unavailable'].freeze

  AGENT_LIMIT_KEY_EXPIRY = 300

  CENTRAL_ADD_REMOVE_KEY = %i[added removed].freeze
  CENTRAL_GROUP_KEYS = %i[groups contribution_groups].freeze
  CENTRAL_SINGLE_ACCESS_TOKEN_KEY = 'single_access_token'.freeze
end