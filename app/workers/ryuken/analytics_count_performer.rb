class Ryuken::AnalyticsCountPerformer < Ryuken::CountPerformer
  include Shoryuken::Worker

  shoryuken_options queue: ::SQS[:analytics_etl_queue],
                    body_parser: :json

  def perform(sqs_msg, args)
    super(sqs_msg, args)
  end
end
