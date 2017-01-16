module RabbitMq::Subscribers::ArchiveTickets::Iris
  
  include RabbitMq::Constants

  def mq_iris_archive_ticket_properties(action)
    to_rmq_json(iris_keys, action)
  end
  
  def mq_iris_subscriber_properties(action)
    {
      :manual_publish => true
    }
    # Iris ETL expects subscriber_properties to be of either model_changes or manual_publish
    # So adding manual_publish in this case       
  end

  def mq_iris_valid(action, model) 
    iris_valid_model?(model) && update_action?(action)
  end

  private

  def iris_keys
    IRIS_ARCHIVE_TICKET_KEYS + [{"custom_fields" => non_text_custom_field.keys}]
  end
  
  def iris_valid_model?(model)
    ["archive_ticket"].include?(model)
  end
end