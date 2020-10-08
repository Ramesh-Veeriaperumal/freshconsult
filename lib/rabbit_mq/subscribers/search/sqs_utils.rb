module RabbitMq::Subscribers::Search::SqsUtils

  def model_properties(model_object, action)
    parent_id = Search::Utils::PARENT_BASED_ROUTING[model_object.class.name]

    Hash.new.tap do |sqs_params|
      sqs_params['document_id'] = model_object.id
      sqs_params['account_id']  = Account.current.try(:id) || model_object.account_id
      sqs_params['klass_name']  = model_object.class.to_s
      sqs_params['type']        = model_object.class.to_s.demodulize.downcase
      sqs_params['action']      = action
      if parent_id
        sqs_params['routing_id']  =  Account.current.try(:id) || model_object.account_id
        sqs_params['parent_id']   =  model_object.safe_send(parent_id)
      end
    end
  end

  def es_v2_valid?(obj, model)
    obj.safe_send('valid_esv2_model?', model)
  end

  # To manually publish to SQS without checks.
  #
  def manual_publish(model_object)
    action          = 'update' #=> Always keeping manual publish as update
    model_name      = model_object.class.name.demodulize.tableize.downcase.singularize
    model_uuid      = RabbitMq::Utils.generate_uuid
    model_exchange  = RabbitMq::Constants::MODEL_TO_EXCHANGE_MAPPING[model_name]
    model_message   = RabbitMq::SqsMessage.skeleton_message(model_name, action, model_uuid, Account.current.try(:id) || model_object.account_id)
    
    model_message["#{model_name}_properties"].deep_merge!(model_object.safe_send("mq_search_#{model_name}_properties", action))
    model_message["subscriber_properties"].merge!({ 'search' => model_object.mq_search_subscriber_properties(action) })
    
    RabbitMq::Utils.manual_publish_to_xchg(
      model_uuid, model_exchange, model_message.to_json, RabbitMq::Constants.const_get("RMQ_SEARCH_#{model_exchange.upcase}_KEY"), true
    )
  end

  module_function :model_properties, :es_v2_valid?, :manual_publish
end
