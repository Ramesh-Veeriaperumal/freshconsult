unless defined?(PhusionPassenger)
  RABBIT_MQ_ENABLED = !Rails.env.development?
  RabbitMq::Init.start if RABBIT_MQ_ENABLED
end