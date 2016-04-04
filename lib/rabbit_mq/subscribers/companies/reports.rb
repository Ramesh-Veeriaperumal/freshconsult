module RabbitMq::Subscribers::Companies::Reports
  
  # TODO Check the columns that must be considered
  PROPERTIES_TO_CONSIDER = ["name", "sla_policy_id"]
  
  def mq_reports_company_properties(action)
    to_rmq_json
  end

  def mq_reports_subscriber_properties(action)
    {}
  end

  def mq_reports_valid(action, model)
    false
    # currently commenting out the code
    # valid_model?(model) && (create_action?(action) || destroy_action?(action) || @model_changes.keys.select {|key|  valid_key?(key) }.any?)
  end
  
  private
  
    def valid_key?(key)
      PROPERTIES_TO_CONSIDER.include?(key) || non_text_ff_fields.include?(key)
    end
    
    def valid_model?(model)
      ["company"].include?(model)
    end
  
end