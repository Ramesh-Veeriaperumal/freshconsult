module Helpdesk::TicketModelExtension

  include Helpdesk::TicketModelExtension::Constants

  EXPORT_FIELDS = [
    [ "export_data.fields.ticket_id",             "display_id",              true ,  nil              , 1     , nil],
    [ "export_data.fields.subject",               "subject",                 true ,  nil              , 2     , nil],
    [ "export_data.fields.status",                "status_name",             true ,  nil              , 4     , nil],
    [ "export_data.fields.priority",              "priority_name",           false,  nil              , 5     , nil],
    [ "export_data.fields.source",                "source_name",             false,  nil              , 6     , nil], 
    [ "export_data.fields.type",                  "ticket_type",             false,  nil              , 7     , nil],
    [ "export_data.fields.company",               "company_name",            false,  :company         , 8     , nil],
    [ "export_data.fields.requester_name",        "requester_name",          false,  :requester       , 9     , nil],
    [ "export_data.fields.requester_email",       "requester_info",          true ,  :requester       , 10    , nil],
    [ "export_data.fields.requester_phone",       "requester_phone",         false,  :requester       , 11    , nil], 
    [ "export_data.fields.fb_profile_id",         "requester_fb_profile_id", false,  :requester       , 12    , nil],
    [ "export_data.fields.agent",                 "responder_name",          false,  :responder       , 13    , nil], 
    [ "export_data.fields.group",                 "group_name",              false,  :group           , 14    , nil], 
    [ "export_data.fields.created_time",          "created_at",              false,  nil              , 15    , nil], 
    [ "export_data.fields.resolved_time",         "resolved_at",             false,  nil              , 17    , nil], 
    [ "export_data.fields.closed_time",           "closed_at",               false,  nil              , 18    , nil],
    [ "export_data.fields.updated_time",          "updated_at",              false,  nil              , 19    , nil], 
    [ "export_data.fields.time_tracked",          "time_tracked_hours",      false,  :time_sheets     , 21    , nil], 
    [ "export_data.fields.agent_interactions",    "outbound_count",          false,  nil              , 24    , nil], 
    [ "export_data.fields.customer_interactions", "inbound_count",           false,  nil              , 25    , nil],
    [ "export_data.fields.tags",                  "ticket_tags",             false,  :tags            , 28    , nil], 
    [ "export_data.fields.survey_result",         "ticket_survey_results",   false,  :survey_results  , 29    , "any_survey_feature_enabled?"],
    [ "export_data.fields.skill",                 "skill_name",              false,  nil              , 30    , "skill_based_round_robin_enabled?"],
    [ "export_data.fields.due_by_time",           "due_by",                  false,  nil              , 16    , "sla_management_enabled?"], 
    [ "export_data.fields.initial_response_time", "first_response_time",     false,  nil              , 20    , "sla_management_enabled?"], 
    [ "export_data.fields.fr_time",               "first_res_time_bhrs",     false,  nil              , 22    , "sla_management_enabled?"], 
    [ "export_data.fields.resolution_time",       "resolution_time_bhrs",    false,  nil              , 23    , "sla_management_enabled?"],
    [ "export_data.fields.resolution_status",     "resolution_status",       false,  nil              , 26    , "sla_management_enabled?"],
    [ "export_data.fields.first_response_status", "first_response_status",   false,  nil              , 27    , "sla_management_enabled?"]
  ]

  ASSOCIATION_BY_VALUE = Hash[*EXPORT_FIELDS.map { |i| [i[1], i[3]] }.flatten ]

  def default_export_fields_order
    exportable_fields = Helpdesk::TicketModelExtension.allowed_fields
    fields = Hash[*exportable_fields.map { |i| [i[1], i[4]] }.flatten ]
    fields["description"]   = 3
    fields["product_name"]  = fields.keys.length+1
    fields
  end

  def custom_export_fields_order account = Account.current
    field_mapping = {}
    shift = default_export_fields_order.keys.length
    i = 1+shift  
    account.ticket_fields_including_nested_fields.custom_fields.order("helpdesk_ticket_fields.position").each do |custom_field|
      field_mapping[custom_field.name] = i 
      i = i + 1
      if custom_field.field_type == "nested_field"
        custom_field.nested_ticket_fields.each do |nested_field|
          field_mapping[nested_field.name] = i
          i = i + 1
        end
      end
    end
    field_mapping
  end

  def contact_company_fields_order type
    fields = Account.current.send("#{type}_form")
      .send("#{type}_fields_from_cache")
      .map{|f| [f.name, f.position]}
    count = fields.count
    default_fields = Helpdesk::TicketModelExtension.customer_fields(type)
    (fields + default_fields.map{|f| [f[:value], count+=1]}).to_h
  end

  def self.csv_headers
    self.allowed_fields.map do |i|  
      {:label => I18n.t(i[0]), :value => i[1], :selected => i[2], :feature => i[5] } 
    end
  end

  def self.allowed_fields
    fields = []
    EXPORT_FIELDS.each do |i|
        fields << i if Export::ExportFields.allow_field? i[5]
    end
    fields
  end

  def self.allowed_ticket_fields
    fields = []
    EXP_TICKET_FIELDS.each do |i|
        fields << i if Export::ExportFields.allow_field? i[5]
    end
    fields
  end

  def self.field_name(value)
    FIELD_NAME_MAPPING[value].blank? ? value : FIELD_NAME_MAPPING[value]
  end

  def self.ticket_csv_headers
    self.allowed_ticket_fields.map do |i| 
      {:label => I18n.t(i[0]), :value => i[1], :selected => i[2] }
    end
  end

  def self.customer_fields type
    fields = type.eql?('contact') ? CONTACT_FIELDS : COMPANY_FIELDS
    fields.map do |i| 
       {:label => I18n.t(i[0]), :value => i[1], :selected => i[2] }
    end
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
