class Ryuken::ArchiveSearchPoller < Ryuken::SearchPoller
  include Shoryuken::Worker

  shoryuken_options queue: ::ES_V2_ARCHIVE_POLLER_QUEUES,
                    body_parser: :json
                    # retry_intervals: [360, 1200, 3600] #=> Depends on visibility timeout
                    # batch: true, #=> Batch processing. Max 10 messages. sqs_msg, args = ARRAY
                    # auto_delete: true
end