module Search
  module V2

    module SqsSkeleton

      def model_properties(model_object, action)
        parent_id = Search::Utils::PARENT_BASED_ROUTING[model_object.class.name]

        Hash.new.tap do |sqs_params|
          sqs_params['document_id'] = model_object.id
          sqs_params['account_id']  = model_object.account_id
          sqs_params['klass_name']  = model_object.class.to_s
          sqs_params['type']        = model_object.class.to_s.demodulize.downcase
          sqs_params['action']      = action
          if parent_id
            sqs_params['routing_id']  =  model_object.account_id
            sqs_params['parent_id']   =  model_object.send(parent_id)
          end
        end
      end

      def es_v2_valid?(obj, model)
        Account.current.features_included?(:es_v2_writes) && obj.send('valid_esv2_model?', model)
      end

      # Using action create instead of update to avoid valid? check.
      # Create/Update = upsert for search.
      #
      def manual_publish(model_object)
        model_name = model_object.class.name.demodulize.tableize.downcase.singularize
        exchange = RabbitMq::Constants::MODEL_TO_EXCHANGE_MAPPING[model_name]
        model_object.send(:publish_to_rabbitmq, exchange, model_name, 'create')
      end

      module_function :model_properties, :es_v2_valid?, :manual_publish
    end

  end
end