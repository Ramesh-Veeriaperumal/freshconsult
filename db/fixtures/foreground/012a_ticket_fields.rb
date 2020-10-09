
account = Account.current

FlexifieldDef.seed(:account_id, :module) do |s|
  s.account_id = account.id
  s.module = "Ticket"
  s.name = "Ticket_#{account.id}"
  s.active = true
end

def self.ticket_fields_data
  [
    { :name => "requester", :label => "Requester", :description => "Ticket requester",
      :required => true, :visible_in_portal => true, :editable_in_portal => true, 
      :required_in_portal => true , :field_options => {"portalcc" => false , "portalcc_to" => "company"} },
      
    { :name => "subject", :label => "Subject", :description => "Ticket subject",
      :required => true, :visible_in_portal => true, :editable_in_portal => true, 
      :required_in_portal => true, field_options: {} },
       
    { :name => "ticket_type", :label => "Type", :description => "Ticket type",
      :required => false, field_options: {},
      :picklist_values => [{ :value => "Question"},
                           { :value => "Incident"},
                           { :value => "Problem"},
                           { :value => "Feature Request"}]
    },
      
    { :name => "source", :label => "Source", :description => "Ticket source", field_options: {} },
      
    { :name => "status", :label => "Status", :description => "Ticket status",
      :required => true, :visible_in_portal => true, field_options: {} },
      
    { :name => "priority", :label => "Priority", :description => "Ticket priority",
      :required => true, field_options: {} },
      
    { :name => "group", :label => "Group", :description => "Ticket group", field_options: {} },
      
    { :name => "agent", :label => "Assigned to", :description => "Agent",
      :visible_in_portal => true, field_options: {} },

    { :name => "product", :label => "Product", 
      :description => "Select the product, the ticket belongs to.",
      :visible_in_portal => true, :editable_in_portal => true, field_options: {} },
      
    { :name => "description", :label => "Description", :description => "Ticket description",
      :required => true, :visible_in_portal => true, :editable_in_portal => true, 
      :required_in_portal => true, field_options: {} },

    { :name => "company", :label => "Company", :description => "Ticket Company",
      :required => true, :visible_in_portal => true, :editable_in_portal => true,
      :required_in_portal => true, field_options: {} }
  ]
end

Helpdesk::TicketField.seed_many(:account_id, :name, 
  ticket_fields_data.each_with_index.map do |f, i|
    field_hash = {
      :account_id => account.id,
      :name => f[:name],
      :label => f[:label],
      :label_in_portal => f[:label],
      :description => f[:description],
      :field_type => "default_#{f[:name]}",
      :position => i + 1,
      :required => f[:required] || false,
      :visible_in_portal => f[:visible_in_portal] || false,
      :editable_in_portal => f[:editable_in_portal] || false,
      :required_in_portal => f[:required_in_portal] || false,
      :required_for_closure => f[:required_for_closure] || false,
      :choices => f[:choices] || [],
      :field_options => f[:field_options],
      :default => true,
      :ticket_form_id => account.ticket_field_def.id
    }
    field_hash.merge!(:picklist_values_attributes => f[:picklist_values]) if f[:name].eql?("ticket_type")
    field_hash
  end
)
