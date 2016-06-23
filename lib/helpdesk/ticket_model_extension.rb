module Helpdesk::TicketModelExtension

   EXPORT_FIELDS = [
      [ "export_data.fields.ticket_id",             "display_id",              true ,  nil              , 1     ],
      [ "export_data.fields.subject",               "subject",                 true ,  nil              , 2     ],
      [ "export_data.fields.status",                "status_name",             true ,  nil              , 4     ],
      [ "export_data.fields.priority",              "priority_name",           false,  nil              , 5     ],
      [ "export_data.fields.source",                "source_name",             false,  nil              , 6     ], 
      [ "export_data.fields.type",                  "ticket_type",             false,  nil              , 7     ],
      [ "export_data.fields.company",               "company_name",            false,  :company         , 8     ],
      [ "export_data.fields.requester_name",        "requester_name",          false,  :requester       , 9     ],
      [ "export_data.fields.requester_email",       "requester_info",          true ,  :requester       , 10    ],
      [ "export_data.fields.requester_phone",       "requester_phone",         false,  :requester       , 11    ], 
      [ "export_data.fields.fb_profile_id",         "requester_fb_profile_id", false,  :requester       , 12    ], 
      [ "export_data.fields.agent",                 "responder_name",          false,  :responder       , 13    ], 
      [ "export_data.fields.group",                 "group_name",              false,  :group           , 14    ], 
      [ "export_data.fields.created_time",          "created_at",              false,  nil              , 15    ], 
      [ "export_data.fields.due_by_time",           "due_by",                  false,  nil              , 16    ], 
      [ "export_data.fields.resolved_time",         "resolved_at",             false,  nil              , 17    ], 
      [ "export_data.fields.closed_time",           "closed_at",               false,  nil              , 18    ], 
      [ "export_data.fields.updated_time",          "updated_at",              false,  nil              , 19    ], 
      [ "export_data.fields.initial_response_time", "first_response_time",     false,  nil              , 20    ], 
      [ "export_data.fields.time_tracked",          "time_tracked_hours",      false, :time_sheets      , 21    ], 
      [ "export_data.fields.fr_time",               "first_res_time_bhrs",     false,  nil              , 22    ], 
      [ "export_data.fields.resolution_time",       "resolution_time_bhrs",    false,  nil              , 23    ], 
      [ "export_data.fields.agent_interactions",    "outbound_count",          false,  nil              , 24    ], 
      [ "export_data.fields.customer_interactions", "inbound_count",           false,  nil              , 25    ], 
      [ "export_data.fields.resolution_status",     "resolution_status",       false,  nil              , 26    ], 
      [ "export_data.fields.first_response_status", "first_response_status",   false,  nil              , 27    ], 
      [ "export_data.fields.tags",                  "ticket_tags",             false, :tags             , 28    ], 
      [ "export_data.fields.survey_result",         "ticket_survey_results",   false, :survey_results   , 29    ]
   ]

   ASSOCIATION_BY_VALUE = Hash[*EXPORT_FIELDS.map { |i| [i[1], i[3]] }.flatten ]

  def default_export_fields_order
    fields = Hash[*EXPORT_FIELDS.map { |i| [i[1], i[4]] }.flatten ]
    fields["description"]   = 3
    fields["product_name"]  = fields.keys.length+1
    fields
  end

  def custom_export_fields_order account = Account.current
    shift = default_export_fields_order.keys.length
    fields = account.ticket_fields_with_nested_fields.custom_fields.pluck(:name)
    Hash[fields.each_with_index.map {|x,i| [x, i+1+shift]}]
  end

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
