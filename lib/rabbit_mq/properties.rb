module RabbitMq::Properties
  
  def get_properties(ticket)
    properties = {
      "ticket_id"         => ticket.display_id,
      "account_id"        => ticket.account_id,
      "responder_name"    => ticket.responder.nil? ? "No Agent" : ticket.responder.name,
      "group_id"          => ticket.group_id,
      "status"            => ticket.status,
      "priority"          => ticket.priority,
      "source"            => ticket.source,
      "subject"           => ticket.subject,
      "description"       => ticket.description[0..50],
      "requester_name"    => ticket.requester.name,
      "due_by"            => ticket.due_by.to_i,
      "actions"           => [], 
      "created_at"        => "#{created_at}",
      "users_notify"      => nil
    }
    return properties
  end

end    