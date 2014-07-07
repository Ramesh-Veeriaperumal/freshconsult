unless defined?(PhusionPassenger)
  RABBIT_MQ_ENABLED = !Rails.env.development? && !Rails.env.test?
  RabbitMq::Init.start if RABBIT_MQ_ENABLED
end