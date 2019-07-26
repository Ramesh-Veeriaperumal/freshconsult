class Ryuken::TwitterTweetToTicket
  include Shoryuken::Worker

  shoryuken_options queue: SQS[:twitter_realtime_queue], auto_delete: true, body_parser: :json, batch: false

  def perform(sqs_msg, _args)
    tweet = sqs_msg.body
    return if tweet.blank?
    gnip_msg = Social::Gnip::TwitterFeed.new(tweet)
    begin
      start_time = Time.now.utc
      Rails.logger.info "social::twitter process tweet_id : #{gnip_msg.tweet_id} : started_at : #{start_time}"
      time_taken = Benchmark.realtime { gnip_msg.process }
      Rails.logger.info "social::twitter processing tweet finished, time taken : #{time_taken}"
    rescue Exception => error
      Rails.logger.error "Exception in processing tweet #{error.message} #{error.backtrace[0..10]} #{tweet}"
      NewRelic::Agent.notice_error(error,
                                   custom_params: {
                                     description: 'Error in processing Gnip Feed',
                                     tweet_obj: tweet
                                   })
      raise error
    end
  end
end
