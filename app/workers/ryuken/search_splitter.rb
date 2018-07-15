# Class to read search events and put into cluster specific queue
#
class Ryuken::SearchSplitter
  include Shoryuken::Worker

  shoryuken_options queue: ::SQS[:search_etl_queue],
    body_parser: :json
  # retry_intervals: [360, 1200, 3600] #=> Depends on visibility timeout
  # batch: true, #=> Batch processing. Max 10 messages. sqs_msg, args = ARRAY
  # auto_delete: true

  def perform(sqs_msg, args)
    begin
      search_payload = args["#{args['object']}_properties"].merge({
        'version' => (args['action_epoch'] * 1000000).ceil
      })

      if args["subscriber_properties"]["search"] && args["subscriber_properties"]["search"]["timestamps"]
        if sqs_msg.attributes["SentTimestamp"]
          args["subscriber_properties"]["search"]["timestamps"] << sqs_msg.attributes["SentTimestamp"].to_i
        end
        args["subscriber_properties"]["search"]["timestamps"] << Search::Job.es_version/1000
        search_payload.merge!({'timestamps' => args["subscriber_properties"]["search"]})
      end

      case search_payload['action']
      when 'destroy'
        Search::V2::Operations::DocumentRemove.new(search_payload).perform
      else
        Search::V2::Operations::DocumentAdd.new(search_payload).perform
      end
      sqs_msg.try :delete
    rescue Exception => e
      Rails.logger.error "Searchv2 exception - #{e.message} - #{e.backtrace.first}"
      NewRelic::Agent.notice_error(e, { arguments: args })
      raise e
    end
  end
end
