module RabbitMq::Subscribers::Tickets::Reports
  
  include RabbitMq::Constants

  PROPERTIES_TO_CONSIDER = [ :requester_id, :responder_id, :group_id, 
                             :priority, :ticket_type, :source,
                             :status, :product_id, :owner_id,
                             :isescalated, :fr_escalated, :spam, :deleted,
                             :long_tc01, :long_tc02, :internal_group_id, :internal_agent_id,
                             :association_type
                           ]

  def mq_reports_ticket_properties(action)
    to_rmq_json(report_keys, action)
  end
  
  def mq_reports_subscriber_properties(action)
    return {} if destroy_action?(action) 
    # Calling the method separately because if exception occures in BusinessCalendar.execute
    # then subscriber properties is returning null without the model changes
    action_in_bhrs_flag = action_in_bhrs?
    { 
      :model_changes => @model_changes ? valid_changes : {} ,
      :action_in_bhrs => action_in_bhrs_flag,
      :lifecycle => (create_action?(action) && resolved_at) ?  get_default_lifecycle_properties : (@ticket_lifecycle || {})
    }
  end

  def mq_reports_valid(action, model) 
    valid = (reports_valid_model?(model) && !archive && (create_action?(action) || non_archive_destroy?(action) || valid_changes.any?))
    Rails.logger.debug "#{Account.current.id} --- #{model} --- #{valid}"
    valid
  end

  private
  
  # For archive tickets, we do ticket destroy. But before destroying, it will send a
  # manual push to rabbitmq. So ignoring it, when destroy callback is triggered with archive set to true
  def non_archive_destroy?(action)
    destroy_action?(action) && !archive
  end

  def report_keys
    REPORTS_TICKET_KEYS + [{"custom_fields" => non_text_ff_aliases}]
  end
  
  def valid_changes
    changes = @model_changes.select{|k,v| PROPERTIES_TO_CONSIDER.include?(k) ||  non_text_ff_fields.include?(k.to_s) }
    changes
  end

  def reports_valid_model?(model)
    ["ticket"].include?(model)
  end

  
  def action_in_bhrs?
    BusinessCalendar.execute(self) do
      action_occured_in_bhrs?(Time.zone.now, group)
    end
  end

end