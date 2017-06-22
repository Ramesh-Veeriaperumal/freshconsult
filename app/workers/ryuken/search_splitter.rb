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
      if args["subscriber_properties"]["search"]
        if sqs_msg.attributes["SentTimestamp"]
          args["subscriber_properties"]["search"]["timestamps"] << sqs_msg.attributes["SentTimestamp"].to_i
        end
        args["subscriber_properties"]["search"]["timestamps"] << Search::Job.es_version/1000
      end
      cluster = Search::V2::Tenant.new(Account.current.id).home_cluster
      if args["#{args['object']}_properties"]['archive'].presence
        Ryuken::SearchPoller.perform_async(args.to_json, queue: ES_V2_QUEUE_KEY % { cluster: (cluster + '-archive') })
      else
        Ryuken::SearchPoller.perform_async(args.to_json, queue: ES_V2_QUEUE_KEY % { cluster: cluster })
      end
      sqs_msg.delete
    rescue Exception => e
      Rails.logger.error "Searchv2 exception - #{e.message} - #{e.backtrace.first}"
      NewRelic::Agent.notice_error(e, { arguments: args })
      raise e
    end
  end
end