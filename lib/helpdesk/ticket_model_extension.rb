module Helpdesk::TicketModelExtension

   EXPORT_FIELDS = [
      [ "export_data.fields.ticket_id",             "display_id",              true                   ],
      [ "export_data.fields.subject",               "subject",                 true                   ],
      [ "export_data.fields.description",           "description",             false                  ],
      [ "export_data.fields.status",                "status_name",             true                   ],
      [ "export_data.fields.priority",              "priority_name",           false                  ],
      [ "export_data.fields.source",                "source_name",             false                  ], 
      [ "export_data.fields.type",                  "ticket_type",             false                  ],
      [ "export_data.fields.company",               "company_name",            false, :company        ],
      [ "export_data.fields.requester_name",        "requester_name",          false, :requester      ],
      [ "export_data.fields.requester_email",       "requester_info",          true , :requester      ],
      [ "export_data.fields.requester_phone",       "requester_phone",         false, :requester      ], 
      [ "export_data.fields.fb_profile_id",         "requester_fb_profile_id", false, :requester      ], 
      [ "export_data.fields.agent",                 "responder_name",          false, :responder      ], 
      [ "export_data.fields.group",                 "group_name",              false, :group          ], 
      [ "export_data.fields.created_time",          "created_at",              false                  ], 
      [ "export_data.fields.due_by_time",           "due_by",                  false                  ], 
      [ "export_data.fields.resolved_time",         "resolved_at",             false                  ], 
      [ "export_data.fields.closed_time",           "closed_at",               false                  ], 
      [ "export_data.fields.updated_time",          "updated_at",              false                  ], 
      [ "export_data.fields.initial_response_time", "first_response_time",     false                  ], 
      [ "export_data.fields.time_tracked",          "time_tracked_hours",      false, :time_sheets    ], 
      [ "export_data.fields.fr_time",               "first_res_time_bhrs",     false                  ], 
      [ "export_data.fields.resolution_time",       "resolution_time_bhrs",    false                  ], 
      [ "export_data.fields.agent_interactions",    "outbound_count",          false                  ], 
      [ "export_data.fields.customer_interactions", "inbound_count",           false                  ], 
      [ "export_data.fields.resolution_status",     "resolution_status",       false                  ], 
      [ "export_data.fields.first_response_status", "first_response_status",   false                  ], 
      [ "export_data.fields.tags",                  "ticket_tags",             false, :tags           ], 
      [ "export_data.fields.survey_result",         "ticket_survey_results",   false, :survey_results ]
   ]

   ASSOCIATION_BY_VALUE = Hash[*EXPORT_FIELDS.map { |i| [i[1], i[3]] }.flatten ]

   def self.csv_headers
      EXPORT_FIELDS.map do |i| 
         {:label => I18n.t(i[0]), :value => i[1], :selected => i[2] }
      end
   end

   def self.field_name(value)
      FIELD_NAME_MAPPING[value].blank? ? value : FIELD_NAME_MAPPING[value]
   end

   FIELD_NAME_MAPPING = {
      "status_name" => "status",
      "priority_name" => "priority",
      "source_name" => "source",
      "requester_info" => "requester",
      "responder_name" => "agent",
      "group_name" => "group"
   }
end
