module RabbitMq::Subscribers::Tickets::MobileApp

  def mq_mobile_app_ticket_properties(action)
    {
      "ticket_id"         => display_id,
      "group"             => group_name,
      "status_name"       => status_name,
      "requester"         => requester_name,
      "subject"           => truncate(subject, :length => 100),
      "priority"          => priority
    }
  end

  def mq_mobile_app_subscriber_properties
    {
      
    }
  end

  def mq_mobile_app_valid
    @model_changes.key?(:responder_id) || @model_changes.key?(:group_id) || @model_changes.key?(:status)
  end
end