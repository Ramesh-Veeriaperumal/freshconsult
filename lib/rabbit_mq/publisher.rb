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

  #This method will be called from included model to return model specific keys     
  #that are requied in model properties. Moving this method here so as to avoic   
  #having it in all models.   
  def return_specific_keys(hash, keys)    
    new_hash = {}   
      keys.each do |key|    
        if key.class.name == "String"   
          new_hash[key] = hash[key]   
        elsif key.class.name == "Hash"    
          current_key = key.keys.first    
          if !hash[current_key].nil?    
            new_hash[current_key] = return_specific_keys(hash[current_key], key[current_key])   
          end   
        end   
      end   
    new_hash    
  end
end