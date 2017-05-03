module Helpdesk::TicketModelExtension::Constants

  #Used in Scheduled Ticket Export

  EXP_TICKET_FIELDS = [
    [ "export_data.fields.ticket_id",             "display_id",              true ,  nil              , 1     , nil],
    [ "export_data.fields.subject",               "subject",                 true ,  nil              , 2     , nil],
    [ "export_data.fields.status",                "status_name",             true ,  nil              , 4     , nil],
    [ "export_data.fields.priority",              "priority_name",           false,  nil              , 5     , nil],
    [ "export_data.fields.source",                "source_name",             false,  nil              , 6     , nil], 
    [ "export_data.fields.type",                  "ticket_type",             false,  nil              , 7     , nil],
    [ "export_data.fields.agent",                 "responder_name",          false,  :responder       , 13    , nil], 
    [ "export_data.fields.group",                 "group_name",              false,  :group           , 14    , nil], 
    [ "export_data.fields.created_time",          "created_at",              false,  nil              , 15    , nil], 
    [ "export_data.fields.resolved_time",         "resolved_at",             false,  :ticket_states   , 17    , nil], 
    [ "export_data.fields.closed_time",           "closed_at",               false,  :ticket_states   , 18    , nil],
    [ "export_data.fields.updated_time",          "updated_at",              false,  nil              , 19    , nil], 
    [ "export_data.fields.time_tracked",          "time_tracked_hours",      false, :time_sheets      , 21    , nil], 
    [ "export_data.fields.agent_interactions",    "outbound_count",          false, :ticket_states    , 24    , nil], 
    [ "export_data.fields.customer_interactions", "inbound_count",           false, :ticket_states    , 25    , nil],
    [ "export_data.fields.tags",                  "ticket_tags",             false, :tags             , 28    , nil], 
    [ "export_data.fields.survey_result",         "ticket_survey_results",   false, :survey_results   , 29    , "any_survey_feature_enabled?"],
    [ "export_data.fields.skill",                 "skill_name",              false,  nil              , 30    , "skill_based_round_robin_enabled?"],
    [ "export_data.fields.due_by_time",           "due_by",                  false,  nil              , 16    , "sla_management_enabled?"], 
    [ "export_data.fields.initial_response_time", "first_response_time",     false,  :ticket_states   , 20    , "sla_management_enabled?"], 
    [ "export_data.fields.fr_time",               "first_res_time_bhrs",     false,  :ticket_states   , 22    , "sla_management_enabled?"], 
    [ "export_data.fields.resolution_time",       "resolution_time_bhrs",    false,  :ticket_states   , 23    , "sla_management_enabled?"],
    [ "export_data.fields.resolution_status",     "resolution_status",       false,  :ticket_states   , 26    , "sla_management_enabled?"],
    [ "export_data.fields.first_response_status", "first_response_status",   false,  :ticket_states   , 27    , "sla_management_enabled?"]
  ]

  CONTACT_FIELDS = [
    [ "export_data.fields.fb_id",                 "fb_profile_id",           false,  :requester       , 2    , nil]
  ]

  COMPANY_FIELDS = []

end