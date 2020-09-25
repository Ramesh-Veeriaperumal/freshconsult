class Group < ActiveRecord::Base

  TICKET_ASSIGN_TYPE = {
    default: 0,
    round_robin: 1, 
    skill_based: 2,
    load_based_omni_channel_assignment: 10,
    lbrr_by_omniroute: 12
  }.freeze

  TICKET_ASSIGN_TYPE_BY_KEYS = Hash[*TICKET_ASSIGN_TYPE.map { |i| [i[1], i[0]] }.flatten]

  OMNIROUTE_POWERED_RR_ASSIGNMENT_TYPES = [12].freeze

  OMNI_CHANNEL_ASSIGNMENT_TYPES = [10, 12].freeze

  AUTOMATIC_TICKET_ASSIGNMENT_TYPES = [1, 2, 10, 12].freeze

  VERSION_MEMBER_KEY = 'AGENTS_GROUPS_LIST'.freeze

  API_OPTIONS = {
    :except  => [:account_id,:email_on_assign,:import_id],
    :include => { 
      :agents => {
        :only => [:id,:name,:email,:created_at,:updated_at,:active,:job_title,
                  :phone,:mobile,:twitter_id, :description,:time_zone,:deleted,
                  :helpdesk_agent,:fb_profile_id,:external_id,:language,:address, :unique_external_id],
        :methods => [:company_id] 
      }
    }
  }
    
  ASSIGNTIME = [
    [ :half,    I18n.t("group.assigntime.half"),      1800 ], 
    [ :one,     I18n.t("group.assigntime.one"),       3600 ], 
    [ :two,     I18n.t("group.assigntime.two"),       7200 ], 
    [ :four,    I18n.t("group.assigntime.four"),      14400 ], 
    [ :eight,   I18n.t("group.assigntime.eight"),     28800 ], 
    [ :twelve,  I18n.t("group.assigntime.twelve"),    43200 ], 
    [ :day,     I18n.t("group.assigntime.day"),       86400 ],
    [ :twoday,  I18n.t("group.assigntime.twoday"),    172800 ], 
    [ :threeday,I18n.t("group.assigntime.threeday"),  259200 ],
  ]

  TICKET_ASSIGN_OPTIONS = [
                            ['group_ticket_options.default',         '0'], 
                            ['group_ticket_options.round_robin',     '1'],
                            ['group_ticket_options.skill_based',     '2']
                          ]

  ASSIGNTIME_OPTIONS = ASSIGNTIME.map { |i| [i[1], i[2]] }
  ASSIGNTIME_NAMES_BY_KEY = Hash[*ASSIGNTIME.map { |i| [i[2], i[1]] }.flatten]
  ASSIGNTIME_KEYS_BY_TOKEN = Hash[*ASSIGNTIME.map { |i| [i[0], i[2]] }.flatten]
  MAX_CAPPING_LIMIT = 100
  CAPPING_LIMIT_OPTIONS = (2..MAX_CAPPING_LIMIT).map { |i| 
    ["#{i} #{I18n.t("group.capping_tickets")}", i] 
    }.insert(0, ["1 #{I18n.t("group.capping_ticket")}", 1])
  NON_DEFAULT_BUSINESS_HOURS = { 'business_calendars.is_default': false }

  GROUP_TYPE = {
    support_agent_groups: 1,
    field_agent_groups: 2
  }
end
