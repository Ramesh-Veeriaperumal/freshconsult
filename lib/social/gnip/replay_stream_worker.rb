class Social::Gnip::ReplayStreamWorker
  include Social::Gnip::Constants

  @queue = "replay_stream_worker"

  def self.perform(options)
    @queue = $sqs_twitter
    start_replay(options)
  end


  def self.start_replay(options)
    options.symbolize_keys!
    gnip_url = GnipConfig::URL['replay_stream_url'] + '?fromDate=' + 
                          options[:start_time] + '&toDate=' + options[:end_time]

    Curl::Easy.http_get gnip_url do |c|
      c.http_auth_types =  :basic
      c.username = GnipConfig::URL['user_name']
      c.password = GnipConfig::URL['password']

      c.encoding = "gzip"
      c.verbose = true

      c.low_speed_limit = 1
      c.low_speed_time = TIME[:replay_stream_timeout]

      c.on_body do |tweet|
        if !(tweet.eql?(DELIMITER[:replay_stream]) || tweet.eql?(DELIMITER[:production_stream]))
          tweet_dup = tweet.dup
          #This is to ensure that aws-sdk send_message works properly with non UTF-8 chars
          tweet_dup.force_encoding("UTF-8")
          @queue.send_message(tweet_dup)
        end
        tweet.size
      end

      c.on_failure do |easy,code|
        NewRelic::Agent.notice_error("Replay Stream Worker Failed", :custom_params =>
                  {:params => options}) 
        sleep 5
        $redis_others.lpush(GNIP_DISCONNECT_LIST,
                              [options[:start_time],options[:end_time]].to_json)
      end

    end
    rescue => e
      puts "Exception in fetching tweets from replay worker #{e.backtrace.join("\n")} #{e.to_s}"
      NewRelic::Agent.notice_error(e.to_s, :custom_params => {
                    :description => "Exception in fetching tweets from replay worker stream" }) 
      $redis_others.lpush(GNIP_DISCONNECT_LIST,
                              [options[:start_time],options[:end_time]].to_json)
  end
end
