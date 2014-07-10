module Social::Twitter::Constants

  TAG_PREFIX = "S"

  MSG_COUNT_FOR_UPDATING_REDIS = 15

  GNIP_DISCONNECT_LIST = "gnip_disconnect"

  #Stream and Ticket Rule type
  STREAM_TYPE = {
    :default => "Mention",
    :dm => "DM",
    :custom => "Custom"
  }

  # time in sec
  TIME = {
    :max_time_in_sqs => 120,
    :reconnect_timeout => 30,
    :replay_stream_wait_time => 1800
  }
  
  MAX_LIVE_TWEET_COUNT = 500

  TWITTER_RULE_OPERATOR = {
    :and => " ",
    :or => " OR ",
    :neg => " -",
    :from => "from:",
    :ignore_rt => "-rt"
  }
  
  AVATAR_SIZES = ["normal", "bigger", "mini"]
  
  SEARCH_RESULT_TYPE = {
    :mixed => "mixed",
    :recent => "recent",
    :top => "top"
  }

  RETWEETS_COUNT =  15
  
  LIVE_SEARCH_COUNT = 15
  
  MAX_SEARCH_RESULTS_COUNT = 100
  
  OTHER_INTERACTIONS_COUNT = 10

end
