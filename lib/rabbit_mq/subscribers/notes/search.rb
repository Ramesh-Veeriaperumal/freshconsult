module RabbitMq::Subscribers::Notes::Search

  def mq_search_valid(action, model)
    Search::V2::SqsSkeleton.es_v2_valid?(self, model) && human_note_for_ticket?
  end

  def mq_search_note_properties(action)
    @esv2_note_identifiers ||= Search::V2::SqsSkeleton.model_properties(self, action)
  end

  def mq_search_subscriber_properties(action)
    {}
  end

  def sqs_manual_publish
    Search::V2::SqsSkeleton.manual_publish(self)
  end

  private

    def valid_esv2_model?(model)
      ['note'].include?(model)
    end

end