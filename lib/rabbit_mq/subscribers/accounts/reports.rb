module RabbitMq::Subscribers::Accounts::Reports
  
  def mq_reports_account_properties(action)
    { :id => id }
  end

  def mq_reports_subscriber_properties(action)
    {}
  end

  def mq_reports_valid(action, model)
    reports_enabled? && valid_model?(model) && destroy_action?(action)
  end
  
  private
    
    def valid_model?(model)
      ["account"].include?(model)
    end
end