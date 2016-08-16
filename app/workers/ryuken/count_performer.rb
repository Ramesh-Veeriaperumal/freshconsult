class Ryuken::CountPerformer
  include Shoryuken::Worker
  
  shoryuken_options queue: ::SQS[:count_etl_queue],
                    body_parser: :json
                    # retry_intervals: [360, 1200, 3600] #=> Depends on visibility timeout
                    # batch: true, #=> Batch processing. Max 10 messages. sqs_msg, args = ARRAY
                    # auto_delete: true
  
  def perform(sqs_msg, args)
    begin
      return unless Account.current.features?(:countv2_writes)
      search_payload = args["#{args['object']}_properties"].merge({
        'version' => (args['action_epoch'] * 1000000).ceil
      })
      case search_payload['action']
      when 'destroy'
        Search::Dashboard::Count.new(search_payload).remove_es_count_document
      else
        Search::Dashboard::Count.new(search_payload).index_es_count_document
      end
      sqs_msg.delete
    rescue Exception => e
      Rails.logger.error "Count ES exception - #{e.message} - #{e.backtrace.first}"
      NewRelic::Agent.notice_error(e, { arguments: args })
      raise e
    end
  end
end
