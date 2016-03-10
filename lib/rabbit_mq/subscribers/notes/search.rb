module RabbitMq::Subscribers::Notes::Search

  include RabbitMq::Subscribers::Search::Sqs
  alias :mq_search_note_properties :mq_search_model_properties

  def mq_search_valid(action, model)
    RabbitMq::Subscribers::Search::SqsUtils.es_v2_valid?(self, model) && human_note_for_ticket?
  end

  private

    def valid_esv2_model?(model)
      ['note'].include?(model)
    end

end