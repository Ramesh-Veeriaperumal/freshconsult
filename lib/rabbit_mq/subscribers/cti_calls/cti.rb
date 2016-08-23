module RabbitMq::Subscribers::CtiCalls::Cti
  
  include RabbitMq::Constants

  def mq_cti_cti_call_properties(action)
    user_id = User.current ? User.current.id : ""
    to_rmq_json(CTI_CALL_KEYS)
  end

  def mq_cti_subscriber_properties(action)
    {}
  end

  def mq_cti_valid(action, model)
    (valid_model?(model) && cti_allowed?)
  end

  private

  def valid_model?(model)
    ["cti_call"].include?(model)
  end

  def to_rmq_json(keys)
    new_hash = {}
    keys.each do |key|
      new_hash[key] = send(key) if key.class.name == "String"
    end
    new_hash
  end
end