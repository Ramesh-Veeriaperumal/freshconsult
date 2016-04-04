class Account < ActiveRecord::Base
    
  def rabbit_mq_exchange(model_name)
    $rabbitmq_model_exchange[rabbit_mq_exchange_key(model_name)]
  end

  def rabbit_mq_exchange_key(model_name)
    "#{model_name.pluralize}_#{id%($rabbitmq_shards)}"
  end
  
end