class Gnip::ReplayClient

  # For replay streams, we need the source, fromDate, toDate and a SQS queue
  # The client will connect to the replay stream and push the feeds into the given queue

  include Gnip::Constants

  def initialize(source, queue, options)
    @source = source
    @queue = queue
    @url = GnipConfig::URL[@source]['replay_stream_url']
    @options = options.symbolize_keys!
  end

  #Returns true if the replay call was successful, false otherwise
  def start_replay()
    topic = SNS["social_notification_topic"]
    DevNotification.publish(topic, "Replay Worker started for #{@source}", @options.to_json)

    gnip_url = @url + '?fromDate=' + @options[:start_time] + '&toDate=' + @options[:end_time]

    Curl::Easy.http_get gnip_url do |c|
      c.http_auth_types =  :basic
      c.username = GnipConfig::URL[@source]['user_name']
      c.password = GnipConfig::URL[@source]['password']

      c.encoding = "gzip"
      c.verbose = true

      c.low_speed_limit = 1
      c.low_speed_time = REPLAY_STREAM_TIMEOUT

      c.on_body do |tweet|
        if !(tweet.eql?(DELIMITER[:replay_stream]) || tweet.eql?(DELIMITER[:production_stream]))
          tweet_dup = tweet.dup
          #This is to ensure that aws-sdk send_message works properly with non UTF-8 chars
          if RUBY_VERSION >= '1.9'
            tweet_dup.force_encoding("UTF-8")
          end
          @queue.send_message(tweet_dup)
        end
        tweet.size
      end

      c.on_failure do |easy,code|
        NewRelic::Agent.notice_error("Replay Stream Worker Failed for #{@source}", :custom_params =>
                  {:params => @options})
        return false
      end
    end
    return true
    rescue => e
      puts "Exception in fetching feeds from #{@source} replay worker #{e.backtrace.join("\n")} #{e.to_s}"
      NewRelic::Agent.notice_error(e.to_s, :custom_params => {
                    :description => "Exception in fetching feeds from #{@source} replay worker stream" })
      return false
  end

end
