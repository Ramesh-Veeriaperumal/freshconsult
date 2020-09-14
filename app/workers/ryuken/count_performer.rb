class Ryuken::CountPerformer
  def perform(sqs_msg, args)
    begin
      search_payload = args["#{args['object']}_properties"].merge(
        'version' => (args['action_epoch'] * 1_000_000).ceil
      )
      case search_payload['action']
      when 'destroy'
        Search::Dashboard::Count.new(search_payload).remove_es_count_document
      else
        Search::Dashboard::Count.new(search_payload).index_es_count_document
      end
      sqs_msg.delete
    rescue Exception => e
      Rails.logger.error "Count ES exception - #{e.message} - #{e.backtrace.first}"
      NewRelic::Agent.notice_error(e, arguments: args)
      raise e
    end
  end
end
