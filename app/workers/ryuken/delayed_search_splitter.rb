class Ryuken::DelayedSearchSplitter < Ryuken::SearchSplitter
  include Shoryuken::Worker

  shoryuken_options queue: ::SQS[:search_etlqueue_maintenance],
                    body_parser: :json

  def perform(sqs_msg, args)
    super(sqs_msg, args)
  end
end
