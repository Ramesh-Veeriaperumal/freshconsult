module RabbitMq::Subscribers::ArchiveTickets::Reports
  
  include RabbitMq::Constants

  def mq_reports_archive_ticket_properties(action)
    to_rmq_json(report_keys, action)
  end
  
  def mq_reports_subscriber_properties(action)
    {
      :manual_publish => true
    }
    # Reports ETL expects subscriber_properties to be of either model_changes or manual_publish
    # So adding manual_publish in this case       
  end

  def mq_reports_valid(action, model) 
    account.features_included?(:bi_reports) and valid_model?(model) and update_action?(action)
  end

  private

  def report_keys
    REPORTS_ARCHIVE_TICKET_KEYS + [{"custom_fields" => non_text_custom_field.keys}]
  end
  
  def valid_model?(model)
    ["archive_ticket"].include?(model)
  end
end