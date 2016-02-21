module RabbitMq::Subscribers::Users::Search

  def mq_search_valid(action, model)
    Search::V2::SqsSkeleton.es_v2_valid?(self, model) && 
    ((update_action?(action) && self.respond_to?(:esv2_fields_updated?)) ? self.esv2_fields_updated? : true)
  end

  def mq_search_user_properties(action)
    @esv2_user_identifiers ||= Search::V2::SqsSkeleton.model_properties(self, action)
  end

  def mq_search_user_email_properties(action)
    @esv2_user_email_identifiers ||= Search::V2::SqsSkeleton.model_properties(self.user, 'update')
  end

  def mq_search_subscriber_properties(action)
    {}
  end

  def sqs_manual_publish
    Search::V2::SqsSkeleton.manual_publish(self)
  end

  private

    def valid_esv2_model?(model)
      ['user', 'user_email'].include?(model)
    end

end