class Ryuken::DelayedAnalyticsCountPerformer < Ryuken::AnalyticsCountPerformer
  include Shoryuken::Worker

  shoryuken_options queue: ::SQS[:analytics_etl_queue_maintenance],
                    body_parser: :json

  def perform(sqs_msg, args)
    super(sqs_msg, args)
  end
end
