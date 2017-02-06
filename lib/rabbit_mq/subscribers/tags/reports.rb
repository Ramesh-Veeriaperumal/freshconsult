module RabbitMq::Subscribers::Tags::Reports
  
  include RabbitMq::Constants

  def mq_reports_tags_properties(action)
    to_rmq_json
  end
  
  def mq_reports_subscriber_properties(action)
    return {} 
  end

  def mq_reports_valid(action, model) 
    valid_model?(model) && destroy_action?(action)
  end

  private

    def valid_model?(model)
      ["tags"].include?(model)
    end

end
