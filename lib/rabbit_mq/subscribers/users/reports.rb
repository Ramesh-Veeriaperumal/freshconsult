module RabbitMq::Subscribers::Users::Reports
  
  # TODO check the columns that must be considered
  PROPERTIES_TO_CONSIDER = ["name", "email", "customer_id" ]
  
  def mq_reports_user_properties(action)
    to_rmq_json
  end

  def mq_reports_subscriber_properties(action)
    {}
  end

  def mq_reports_valid(action, model)
    false
    # TODO currently commenting out the code
    # valid_model?(model) && (create_action?(action) || destroy_action?(action) || @model_changes.keys.select {|key|  valid_key?(key) }.any?)
  end
  
  private
  
    def valid_key?(key)
      PROPERTIES_TO_CONSIDER.include?(key) || non_text_ff_fields.include?(key)
    end
    
    def valid_model?(model)
      ["user"].include?(model)
    end

end