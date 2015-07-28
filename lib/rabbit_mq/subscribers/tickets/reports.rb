module RabbitMq::Subscribers::Tickets::Reports
  
  include RabbitMq::Constants

  PROPERTIES_TO_CONSIDER = [ :requester_id, :responder_id, :group_id, 
                             :priority, :ticket_type, :source,
                             :status, :product_id,
                             :sla_policy_id, :isescalated, :fr_escalated,
                             :spam, :deleted, :parent_ticket
                           ]

  def mq_reports_ticket_properties(action)
    to_rmq_json(report_keys, action)
  end
  
  def mq_reports_subscriber_properties(action)
    return {} if destroy_action?(action)
    BusinessCalendar.execute(self) do
      { 
        :model_changes => @model_changes ? valid_changes : {},
        :action_in_bhrs => action_occured_in_bhrs?(Time.zone.now, group)
      }
    end
  end

  def mq_reports_valid(action, model) 
    account.features_included?(:bi_reports) and valid_model?(model) and (create_action?(action) || non_archive_destroy?(action) || valid_changes.any?)
  end

  private
  
  # For archive tickets, we do ticket destroy. But before destroying, it will send a
  # manual push to rabbitmq. So ignoring it, when destroy callback is triggered with archive set to true
  # Add the archive check once "archive tickets" feature is rolled out @ARCHIVE
  def non_archive_destroy?(action)
    destroy_action?(action) #&& !self.archive
  end

  def report_keys
    REPORTS_TICKET_KEYS + [{"custom_fields" => non_text_ff_aliases}]
  end
  
  def valid_changes
    @model_changes.select{|k,v| PROPERTIES_TO_CONSIDER.include?(k) ||  non_text_ff_fields.include?(k.to_s) }
  end
  
  def valid_model?(model)
    ["ticket"].include?(model)
  end
end