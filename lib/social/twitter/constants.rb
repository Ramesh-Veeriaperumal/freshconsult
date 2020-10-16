module Social::Twitter::Constants

  TAG_PREFIX = "S"

  MSG_COUNT_FOR_UPDATING_REDIS = 15

  GNIP_DISCONNECT_LIST = "gnip_disconnect"

  #Stream and Ticket Rule type
  TWITTER_STREAM_TYPE = {
    :default => "Mention",
    :dm => "DM",
    :custom => "Custom"
  }
  TWITTER_NOTE_TYPE = {
    dm: 'dm',
    mention: 'mention'
  }.freeze
  TWITTER_ACTIONS = {
    :favorite    => "favorite",
    :unfavorite  => "unfavorite",
    :follow      => "follow",
    :unfollow    => "unfollow",
    :post_tweet  => "update",
    :retweet     => "retweet"
  }

  # time in sec
  TIME = {
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

  DEFAULT_AVATAR = "http://abs.twimg.com/sticky/default_profile_images/default_profile_normal.png"
  
  SEARCH_RESULT_TYPE = {
    :mixed => "mixed",
    :recent => "recent",
    :top => "top"
  }

  RETWEETS_COUNT =  15
  
  LIVE_SEARCH_COUNT = 15
  
  MAX_SEARCH_RESULTS_COUNT = 100
  
  OTHER_INTERACTIONS_COUNT = 10
  
  FOLLOWERS_FETCH_COUNT = 2

  SMART_FILTER_RULE_TYPE = 7

  SMART_FILTER_ON = "1"

  COMMON_REDIRECT_URL = "#{AppConfig['integrations_url'][Rails.env]}/twitter/handle/callback"

  COMMON_REDIRECT_REDIS_PREFIX = "TWITTER_COMMON_AUTH"

  IRIS_NOTIFICATION_TYPE = 'twitter_reply_failure'.freeze

  MONITOR_APP_PERMISSION = 'monitor_app_permission'.freeze

  STATUS_UPDATE_COMMAND_NAME = 'update_twitter_message'.freeze

  SURVEY_DM_COMMAND_NAME = 'send_survey_twitter_dm'.freeze

  DEFAULT_TWITTER_CONTENT = {
    dm: 'View the message on Twitter',
    mention: 'View the tweet on Twitter'
  }.freeze

  DEFAULT_TWITTER_CONTENT_HTML = {
    dm: '<div>View the message on Twitter</div>',
    mention: '<div>View the tweet on Twitter</div>'
  }.freeze
end
