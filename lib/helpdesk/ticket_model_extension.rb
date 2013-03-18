module Helpdesk::TicketModelExtension
  
  def self.csv_headers
     [
      {:label => "Ticket Id", :value => "display_id", :selected => true},
      {:label => "Subject",   :value => "subject",    :selected => true},
      {:label => "Description", :value => "description", :selected => false},
      {:label => "Status",    :value => "status_name", :selected => true},
      {:label => "Priority", :value => "priority_name", :selected => false},
      {:label => "Source", :value => "source_name", :selected => false},
      {:label => "Type", :value => "ticket_type", :selected => false},
      {:label => "Customer", :value => "customer_name", :selected => false},
      {:label => "Requester", :value => "requester_info", :selected => true},
      {:label => "Agent", :value => "responder_name", :selected => false},
      {:label => "Group", :value => "group_name", :selected => false},
      {:label => "Created Time", :value => "created_at", :selected => false},
      {:label => "Due by Time", :value => "due_by", :selected => false},
      {:label => "Resolved Time", :value => "resolved_at", :selected => false},
      {:label => "Closed Time", :value => "closed_at", :selected => false},
      {:label => "Last Updated Time", :value => "updated_at", :selected => false}
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
