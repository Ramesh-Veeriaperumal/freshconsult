module RabbitMq::Subscribers::Tickets::Reports
  
  include RabbitMq::Constants

  PROPERTIES_TO_CONSIDER = [ :requester_id, :responder_id, :group_id, 
                             :priority, :ticket_type, :source,
                             :status, :product_id, :customer_id,
                             :sla_policy_id, :is_escalated, :fr_escalated,
                             :spam, :deleted, :parent_ticket
                           ]

  def mq_reports_ticket_properties(action)
    to_rmq_json(report_keys, action)
  end
  
  def mq_reports_subscriber_properties(action)
    return {} if destroy_action?(action)
    action_date = Time.zone.now
    subscriber_hash = { 
      :model_changes => valid_changes
      # Add action_in_bhrs key once the new thing goes out
    }
  end

  def mq_reports_valid(action) 
    create_action?(action) || destroy_action?(action) || valid_changes.any?
  end

  private

  def report_keys
    REPORTS_TICKET_KEYS + [{"custom_fields" => non_text_ff_aliases}]
  end
  
  def valid_changes
    @model_changes.select{|k,v| PROPERTIES_TO_CONSIDER.include?(k) ||  non_text_ff_fields.include?(k.to_s) }
  end
end