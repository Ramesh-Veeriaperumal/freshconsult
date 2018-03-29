class Ryuken::ScheduledExportPayloadEnricher

  include Shoryuken::Worker

  UTC = 'UTC'.freeze
  shoryuken_options queue: SQS[:scheduled_export_payload_enricher_queue], auto_delete: true, 
                    body_parser: :json

  def perform(sqs_msg, args)
    Sharding.run_on_slave do
      set_timezone_utc {
        Rails.logger.info("Inside Enricher :: #{args.inspect}")
        export_fields_data  = Export::EnricherHelper.export_fields_data_from_cache
        payload_enricher    = Export::EnricherHelper.create_payload_enricher(args, export_fields_data)
        enriched_data       = payload_enricher.enrich
        AwsWrapper::SqsV2.send_message(SQS[payload_enricher.queue_name], enriched_data.to_json)
        Rails.logger.info("After Enricher :: #{enriched_data.inspect}")
      }
    end
  rescue Exception => e
    Rails.logger.error "[Ryuken::ScheduledExportPayloadEnricher] sqs message => #{sqs_msg} --->
                          args => #{args}, exception => #{e.message} ---> 
                          #{e.backtrace.inspect}"
    NewRelic::Agent.notice_error(e, { arguments: args })
  end

  private

  def set_timezone_utc(&block)
    Time.use_zone(UTC, &block)
  end

end