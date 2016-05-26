# Class to receive cluster specific events and publish to ES
#
class Ryuken::SearchPoller
  include Shoryuken::Worker

  shoryuken_options queue: (ES_V2_QUEUE_KEY % { cluster: 'cluster1' }),
                    body_parser: :json
                    # retry_intervals: [360, 1200, 3600] #=> Depends on visibility timeout
                    # batch: true, #=> Batch processing. Max 10 messages. sqs_msg, args = ARRAY
                    # auto_delete: true
  
  def perform(sqs_msg, args)
    begin  
      search_payload = args["#{args['object']}_properties"].merge({
        'version' => (args['action_epoch'] * 1000000).ceil
      })
      
      case search_payload['action']
      when 'destroy'
        Search::V2::Operations::DocumentRemove.new(search_payload).perform
      else
        Search::V2::Operations::DocumentAdd.new(search_payload).perform
      end
      sqs_msg.delete
    rescue => e
      Rails.logger.error "Searchv2 exception - #{e.message} - #{e.backtrace.first}"
      NewRelic::Agent.notice_error(e, { arguments: args })
      raise e
    end
  end
end