module RabbitMq::Subscribers::Tickets::AutoRefresh

  def mq_auto_refresh_ticket_properties(action)
    user_id = User.current ? User.current.id : ""
    ticket_responder_id = responder_id ? responder_id : -1
    properties = {
      "ticket_id"         => display_id,
      "user_id"           => user_id,
      "responder_id"      => ticket_responder_id,
      "group_id"          => group_id,
      "status"            => status,
      "priority"          => priority,
      "ticket_type"       => ticket_type,
      "source"            => source,
      "requester_id"      => requester_id,
      "due_by"            => (due_by - Time.zone.now).div(3600),
      "created_at"        => "#{created_at}"
    }
    custom_field_hash = custom_field
    custom_field_hash.blank? ? properties : properties.merge!(custom_field_hash)
  end

  def mq_auto_refresh_subscriber_properties
    {
      "faye_channel" => Faye::AutoRefresh.channel(self.account),
      "messageType" => "publishMessage"
    }
  end

  def mq_auto_refresh_valid
    auto_refresh_allowed? && model_changes?
  end
end