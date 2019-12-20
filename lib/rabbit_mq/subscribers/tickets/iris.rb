module RabbitMq::Subscribers::Tickets::Iris
  
  include RabbitMq::Constants

  PROPERTIES_TO_CONSIDER = [ :requester_id, :responder_id, :group_id, 
                             :priority, :ticket_type, :source,
                             :status, :product_id, :owner_id,
                             :isescalated, :fr_escalated, :spam, :deleted,
                             :long_tc01, :long_tc02, :internal_group_id, :internal_agent_id,
                             :association_type, :due_by ] + SLA_KEYS.map(&:to_sym)

  def mq_iris_ticket_properties(action)
    to_rmq_json(iris_keys, action)
  end
  
  def mq_iris_subscriber_properties(action)
    return {} if destroy_action?(action) 
    # Calling the method separately because if exception occures in BusinessCalendar.execute
    # then subscriber properties is returning null without the model changes
    action_in_bhrs_flag = iris_action_in_bhrs?
    { 
      :model_changes => @model_changes ? iris_valid_changes : {} ,
      :action_in_bhrs => action_in_bhrs_flag
    }.merge(sla_notification_params.present? ? { additional_info: { notify_agents: agents_to_notify_sla } } : {})
  end

  def mq_iris_valid(action, model)
    valid = (iris_valid_model?(model) && !archive && (create_action?(action) || iris_non_archive_destroy?(action) || iris_valid_changes.any?))
    Rails.logger.debug "#{Account.current.id} --- #{model} --- #{valid}"
    valid
  end

  private
  
  # For archive tickets, we do ticket destroy. But before destroying, it will send a
  # manual push to rabbitmq. So ignoring it, when destroy callback is triggered with archive set to true
  def iris_non_archive_destroy?(action)
    destroy_action?(action) && !archive
  end

  def iris_keys
    IRIS_TICKET_KEYS + [{"custom_fields" => non_text_ff_aliases}]
  end
  
  def iris_valid_changes
    changes = @model_changes.dup
    @model_changes.each_pair do |k, v|
      column = Helpdesk::SchemaLessTicket::COLUMN_TO_ATTRIBUTE_MAPPING[k]
      changes[column] = changes.delete(k) if column.present? && SLA_KEYS.include?(column.to_s)
    end
    changes.select { |k, v| PROPERTIES_TO_CONSIDER.include?(k) }
  end

  def iris_valid_model?(model)
    ["ticket"].include?(model)
  end

  
  def iris_action_in_bhrs?
    BusinessCalendar.execute(self) do
      action_occured_in_bhrs?(Time.zone.now, group)
    end
  end
end
