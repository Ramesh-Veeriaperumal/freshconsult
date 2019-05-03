class Ryuken::CountPerformer
  def perform(sqs_msg, args)
    begin
      search_payload = args["#{args['object']}_properties"].merge(
        'version' => (args['action_epoch'] * 1_000_000).ceil
      )
      legacy = args['legacy'].nil? ? true : args['legacy']
      analytics = args['analytics'].nil? ? true : args['analytics']
      case search_payload['action']
      when 'destroy'
        Search::Dashboard::Count.new(search_payload).remove_es_count_document(legacy, analytics)
      else
        Search::Dashboard::Count.new(search_payload).index_es_count_document(legacy, analytics)
      end
      sqs_msg.delete
    rescue Exception => e
      Rails.logger.error "Count ES exception - #{e.message} - #{e.backtrace.first}"
      NewRelic::Agent.notice_error(e, arguments: args)
      raise e
    end
  end
end
