module Helpdesk::TicketModelExtension

  include Helpdesk::TicketModelExtension::Constants

  EXPORT_FIELDS = [
    [ "export_data.fields.ticket_id",             "display_id",              true ,  nil              , 1     , nil],
    [ "export_data.fields.subject",               "subject",                 true ,  nil              , 2     , nil],
    [ "export_data.fields.status",                "status_name",             true ,  :ticket_status   , 4     , nil],
    [ "export_data.fields.priority",              "priority_name",           false,  nil              , 5     , nil],
    [ "export_data.fields.source",                "source_name",             false,  :ticket_source   , 6     , nil],
    [ "export_data.fields.type",                  "ticket_type",             false,  nil              , 7     , nil],
    [ "export_data.fields.company",               "company_name",            false,  :company         , 8     , nil],
    [ "export_data.fields.requester_name",        "requester_name",          false,  :requester       , 9     , nil],
    [ "export_data.fields.requester_email",       "requester_info",          true ,  :requester       , 10    , nil],
    [ "export_data.fields.requester_phone",       "requester_phone",         false,  :requester       , 11    , nil], 
    [ "export_data.fields.fb_profile_id",         "requester_fb_profile_id", false,  :requester       , 12    , nil],
    [ "export_data.fields.agent",                 "responder_name",          false,  :responder       , 13    , nil], 
    [ "export_data.fields.group",                 "group_name",              false,  :group           , 14    , nil], 
    [ "export_data.fields.created_time",          "created_at",              false,  nil              , 15    , nil], 
    [ "export_data.fields.resolved_time",         "resolved_at",             false,  :ticket_states   , 17    , nil],
    [ "export_data.fields.closed_time",           "closed_at",               false,  :ticket_states   , 18    , nil],
    [ "export_data.fields.updated_time",          "updated_at",              false,  nil              , 19    , nil], 
    [ "export_data.fields.time_tracked",          "time_tracked_hours",      false,  :time_sheets     , 21    , nil], 
    [ "export_data.fields.agent_interactions",    "outbound_count",          false,  :ticket_states   , 24    , nil],
    [ "export_data.fields.customer_interactions", "inbound_count",           false,  :ticket_states   , 25    , nil],
    [ "export_data.fields.tags",                  "ticket_tags",             false,  :tags            , 28    , nil], 
    [ "export_data.fields.survey_result",         "ticket_survey_results",   false,  :survey_results  , 29    , "any_survey_feature_enabled?"],
    [ "export_data.fields.skill",                 "skill_name",              false,  nil              , 30    , "skill_based_round_robin_enabled?"],
    [ "export_data.fields.due_by_time",           "due_by",                  false,  nil              , 16    , "sla_management_enabled?"], 
    [ "export_data.fields.initial_response_time", "first_response_time",     false,  :ticket_states   , 20    , "sla_management_enabled?"],
    [ "export_data.fields.fr_time",               "first_res_time_bhrs",     false,  :ticket_states   , 22    , "sla_management_enabled?"],
    [ "export_data.fields.resolution_time",       "resolution_time_bhrs",    false,  :ticket_states   , 23    , "sla_management_enabled?"],
    [ "export_data.fields.resolution_status",     "resolution_status",       false,  :ticket_states   , 26    , "sla_management_enabled?"],
    [ "export_data.fields.first_response_status", "first_response_status",   false,  :ticket_states   , 27    , "sla_management_enabled?"],
    [ "export_data.fields.association_type",      "association_type_name",   false,  nil              , 31    , "link_tkts_or_parent_child_enabled?"],
    [ "export_data.fields.internal_agent",        "internal_agent_name",     false,  :internal_agent  , 32    , "shared_ownership_enabled?"],
    [ "export_data.fields.internal_group",        "internal_group_name",     false,  :internal_group  , 33    , "shared_ownership_enabled?"],
    [ "export_data.fields.every_response_status", "every_response_status",   false,  nil              , 34    , "next_response_sla_enabled?"]
  ]

  ARCHIVE_TICKETS_FIELDS_TO_IGNORE = ["association_type_name", "internal_agent_name", "internal_group_name"]

  ASSOCIATION_BY_VALUE = Hash[*EXPORT_FIELDS.map { |i| [i[1], i[3]] }.flatten ] # Refers to the relation

  DESCRIPTION_INDEX_DEFAULT = 3

  def self.default_export_fields_order
    exportable_fields = Helpdesk::TicketModelExtension.allowed_fields
    fields = Hash[*exportable_fields.map { |i| [i[1], i[4]] }.flatten ]
    fields["description"]   = DESCRIPTION_INDEX_DEFAULT
    fields["product_name"]  = fields.keys.length+1
    fields
  end

  def self.custom_export_fields_order account = Account.current
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

  def self.export_ticket_fields
    default_export_fields_order.merge(custom_export_fields_order)
  end

  def contact_company_fields_order type
    fields = Account.current.safe_send("#{type}_form")
      .safe_send("#{type}_fields_from_cache")
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

  def self.allowed_ticket_export_fields
    fields = []
    EXPORT_FIELDS.each do |i|
      fields << i[1] if (!%i[requester company].include?i[3]) && (Export::ExportFields.allow_field? i[5])
    end
    fields
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
