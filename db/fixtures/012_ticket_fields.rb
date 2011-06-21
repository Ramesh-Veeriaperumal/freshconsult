account = Account.current

FlexifieldDef.seed(:account_id, :module) do |s|
  s.account_id = account.id
  s.module = "Ticket"
  s.name = "Ticket_#{account.id}"
end

Helpdesk::FormCustomizer.seed(:account_id) do |s|
  s.account_id = account.id
  s.name = "Ticket_#{account.id}"
  s.json_data = Helpdesk::FormCustomizer::DEFAULT_FIELDS_JSON
  s.requester_view = Helpdesk::FormCustomizer::DEFAULT_REQUESTER_FIELDS_JSON
end

def self.ticket_fields_data
  [
    { :name => "requester", :label => "Requester", :description => "Ticket requester",
      :required => true, :visible_in_portal => true, :editable_in_portal => true, 
      :required_in_portal => true },
      
    { :name => "subject", :label => "Subject", :description => "Ticket subject",
      :required => true, :visible_in_portal => true, :editable_in_portal => true, 
      :required_in_portal => true },
      
    { :name => "source", :label => "Source", :description => "Ticket source" },
      
    { :name => "ticket_type", :label => "Type", :description => "Ticket type",
      :required => true },
      
    { :name => "status", :label => "Status", :description => "Ticket status",
      :required => true, :visible_in_portal => true },
      
    { :name => "priority", :label => "Priority", :description => "Ticket priority",
      :required => true },
      
    { :name => "group", :label => "Group", :description => "Ticket group" },
      
    { :name => "agent", :label => "Assigned to", :description => "Agent",
      :visible_in_portal => true },
      
    { :name => "description", :label => "Description", :description => "Ticket description",
      :required => true, :visible_in_portal => true, :editable_in_portal => true, 
      :required_in_portal => true }
  ]
end

Helpdesk::TicketField.seed_many(:account_id, :name, 
  ticket_fields_data.each_with_index.map do |f, i|
    {
      :account_id => account.id,
      :name => f[:name],
      :label => f[:label],
      :label_in_portal => f[:label],
      :description => f[:description],
      :field_type => "default_#{f[:name]}",
      :position => i,
      :required => f[:required] || false,
      :visible_in_portal => f[:visible_in_portal] || false,
      :editable_in_portal => f[:editable_in_portal] || false,
      :required_in_portal => f[:required_in_portal] || false,
      :required_for_closure => f[:required_for_closure] || false
    }
  end
)
