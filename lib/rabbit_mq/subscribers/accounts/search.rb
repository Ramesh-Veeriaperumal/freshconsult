module RabbitMq::Subscribers::Accounts::Search

  def mq_search_valid(action, model)
    (destroy_action?(action) || self.features_included?(:es_v2_writes)) && valid_esv2_model?(model) # Destroy based on feature?
  end

  def mq_search_account_properties(action)
    @esv2_account_identifiers ||= Hash.new.tap do |sqs_params|
      sqs_params['document_id'] = self.id
      sqs_params['klass_name']  = self.class.to_s
      sqs_params['action']      = action
    end
  end

  def mq_search_subscriber_properties(action)
    {}
  end

  def sqs_manual_publish
    Search::V2::SqsSkeleton.manual_publish(self)
  end

  private

    def valid_esv2_model?(model)
      ['account'].include?(model)
    end

end