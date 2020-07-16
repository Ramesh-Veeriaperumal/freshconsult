module RabbitMq::Subscribers::TicketOldBodies::Activities
  
  include RabbitMq::Constants
  include ActivityConstants

  PROPERTIES_TO_CONSIDER = [:description]

  def mq_activities_ticket_old_body_properties(action)
    self.ticket.to_rmq_json(ACTIVITIES_TICKET_KEYS, action)
  end

  def ticket_old_body_subscriber_properties(action)
    { object_id: self.ticket.display_id, content: { description: [nil, DONT_CARE_VALUE] }, hypertrail_version: CentralConstants::HYPERTRAIL_VERSION }
  end

  def mq_activities_ticket_old_body_valid(action, model)
    valid_ticket_old_body_model?(model) && ticket_old_body_valid?
  end

  private

  def valid_ticket_old_body_model?(model)
    model == "ticket_old_body"
  end

  def ticket_old_body_valid?
    self.previous_changes.select{|k,v| PROPERTIES_TO_CONSIDER.include?(k.to_sym)}.any?
  end
  
end