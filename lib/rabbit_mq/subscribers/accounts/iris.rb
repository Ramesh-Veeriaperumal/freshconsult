module RabbitMq::Subscribers::Accounts::Iris
  
  def mq_iris_account_properties(action)
    { :id => id }
  end

  def mq_iris_subscriber_properties(action)
    {}
  end

  def mq_iris_valid(action, model)
    iris_valid_model?(model) && destroy_action?(action)
  end
  
  private
    
    def iris_valid_model?(model)
      ["account"].include?(model)
    end
end