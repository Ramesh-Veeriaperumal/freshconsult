module RabbitMq::Subscribers::ArchiveTickets::Activities

  include RabbitMq::Constants
  include ActivityConstants
  PROPERTIES_TO_CONSIDER = [ :requester_id, :company_id ]
  

  def mq_reports_archive_ticket_properties(action)
    to_rmq_json(activities_keys, action) 
  end
  
  def mq_activities_subscriber_properties(action)
    { :object_id => self.display_id, :skip_dashboard => false, :content => valid_changes}
  end

  def mq_activities_valid(action, model)
    false and Account.current.features_included?(:activity_revamp) and valid_model?(model) and update_action?(action) and valid_changes.present?
  end

  def valid_model?(model)
    model == "archive_ticket"
  end

  def valid_changes
    self.changes.dup.select{|k,v| PROPERTIES_TO_CONSIDER.include?(k)}
  end

  def activities_keys
    ACTIVITIES_ARCHIVE_TICKET_KEYS
  end
end

