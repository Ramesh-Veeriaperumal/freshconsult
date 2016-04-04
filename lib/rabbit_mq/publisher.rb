module RabbitMq::Publisher
  include RabbitMq::Utils
  include RabbitMq::Constants
  
  def self.included(base)
    model_name = "#{base}".demodulize.tableize.downcase.singularize
    actions_to_publish = CRUD_NAMES_BY_KEY[MODELS_ACTIONS_TO_PUBLISH[model_name]]
    
    # include the subscribers for the model
    exchange = MODEL_TO_EXCHANGE_MAPPING[model_name]
    RabbitMq::Keys.const_get("#{exchange.upcase}_SUBSCRIBERS").each { |subscriber|
      base.send(:include,
                "RabbitMq::Subscribers::#{exchange.pluralize.camelize}::#{subscriber.camelize}".constantize)
    }
        
    # include the corresponding exchange of the model
    # exchange_name = MODEL_TO_EXCHANGE_MAPPING[model_name]
    # base.send(:include,
    #           "RabbitMq::Exchanges::#{exchange_name.camelize}".constantize)
    
    CRUD.each_with_index do |action, index|
      base.class_eval do
        define_method("#{action}_action?") { |action| action == CRUD[index] }
        if actions_to_publish.include?(action)
          method_name = "publish_#{action}_#{model_name}_to_rabbitmq"
          after_commit :"#{method_name}", on: :"#{action}"
          define_method(method_name) {
            publish_to_rabbitmq(exchange, model_name, action) 
          }
        end
      end
    end
    
  end
end