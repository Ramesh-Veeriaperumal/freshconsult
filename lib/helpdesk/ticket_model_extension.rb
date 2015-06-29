module Helpdesk::TicketModelExtension
  
  def self.csv_headers
     [
      {:label => I18n.t("export_data.fields.ticket_id"), :value => "display_id", :selected => true},
      {:label => I18n.t("export_data.fields.subject"),   :value => "subject",    :selected => true},
      {:label => I18n.t("export_data.fields.description"), :value => "description", :selected => false},
      {:label => I18n.t("export_data.fields.status"),    :value => "status_name", :selected => true},
      {:label => I18n.t("export_data.fields.priority"), :value => "priority_name", :selected => false},
      {:label => I18n.t("export_data.fields.source"), :value => "source_name", :selected => false},
      {:label => I18n.t("export_data.fields.type"), :value => "ticket_type", :selected => false},
      {:label => I18n.t("export_data.fields.company"), :value => "company_name", :selected => false},
      {:label => I18n.t("export_data.fields.requester_name"), :value => "requester_name", :selected => false},
      {:label => I18n.t("export_data.fields.requester_email"), :value => "requester_info", :selected => true},
      {:label => I18n.t("export_data.fields.requester_phone"), :value => "requester_phone", :selected => false},
      {:label => I18n.t("export_data.fields.fb_profile_id"), :value => "requester_fb_profile_id", :selected => false},
      {:label => I18n.t("export_data.fields.agent"), :value => "responder_name", :selected => false},
      {:label => I18n.t("export_data.fields.group"), :value => "group_name", :selected => false},
      {:label => I18n.t("export_data.fields.created_time"), :value => "created_at", :selected => false},
      {:label => I18n.t("export_data.fields.due_by_time"), :value => "due_by", :selected => false},
      {:label => I18n.t("export_data.fields.resolved_time"), :value => "resolved_at", :selected => false},
      {:label => I18n.t("export_data.fields.closed_time"), :value => "closed_at", :selected => false},
      {:label => I18n.t("export_data.fields.updated_time"), :value => "updated_at", :selected => false},
      {:label => I18n.t("export_data.fields.initial_response_time"), :value => "first_response_time", :selected => false},
      {:label => I18n.t("export_data.fields.time_tracked"), :value => "time_tracked_hours", :selected => false},
      {:label => I18n.t("export_data.fields.fr_time"), :value => "first_res_time_bhrs", :selected => false},
      {:label => I18n.t("export_data.fields.resolution_time"), :value => "resolution_time_bhrs", :selected => false},
      {:label => I18n.t("export_data.fields.agent_interactions"), :value => "outbound_count", :selected => false},
      {:label => I18n.t("export_data.fields.customer_interactions"), :value => "inbound_count", :selected => false},
      {:label => I18n.t("export_data.fields.resolution_status"), :value => "resolution_status", :selected => false},
      {:label => I18n.t("export_data.fields.first_response_status"), :value => "first_response_status", :selected => false},
      {:label => I18n.t("export_data.fields.tags"), :value => "ticket_tags", :selected => false},
      {:label => I18n.t("export_data.fields.survey_result"), :value => "ticket_survey_results", :selected => false}
     ]
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
