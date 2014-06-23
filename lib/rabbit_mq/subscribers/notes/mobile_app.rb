module RabbitMq::Subscribers::Notes::MobileApp

  def mq_mobile_app_note_properties
    { 
      "ticket_id"         => notable.display_id,
      "status_name"       => notable.status_name,
      "subject"           => truncate(notable.subject, "length" => 100),
      "priority"          => notable.priority
    }
  end

  def mq_mobile_app_subscriber_properties
    {
         
    }
  end

  def mq_mobile_app_valid
    true  
  end
end