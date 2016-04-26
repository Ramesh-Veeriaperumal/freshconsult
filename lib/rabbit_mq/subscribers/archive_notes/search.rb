module RabbitMq::Subscribers::ArchiveNotes::Search

  include RabbitMq::Subscribers::Search::Sqs
  alias :mq_search_archive_note_properties :mq_search_model_properties

  def mq_search_valid(action, model)
    RabbitMq::Subscribers::Search::SqsUtils.es_v2_valid?(self, model) && !meta?
  end

  private

    def valid_esv2_model?(model)
      ['archive_note'].include?(model)
    end

end