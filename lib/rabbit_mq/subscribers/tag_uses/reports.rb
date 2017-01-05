module RabbitMq::Subscribers::TagUses::Reports
  
  include RabbitMq::Constants

  def mq_reports_tag_use_properties(action)
    to_rmq_json
  end
  
  def mq_reports_subscriber_properties(action)
    return {} 
  end

  def mq_reports_valid(action, model) 
    valid_model?(model)
  end

  private

    def valid_model?(model)
      ["tag_use"].include?(model)
    end

end