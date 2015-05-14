module Mobile::Constants
  MOBILE_NOTIFICATION_CHANNEL_COUNT = 5

  NOTIFCATION_TYPES = {
    :NEW_TICKET => :NEW_TICKET_NOTIFICATION,
    :TICKET_ASSIGNED => :TICKET_ASSIGNED_NOTIFICATION,
    :GROUP_ASSIGNED => :GROUP_ASSIGNED_NOTIFICATION,
    :NEW_RESPONSE => :NEW_RESPONSE_NOTIFICATION,
    :STATUS_UPDATE => :STATUS_UPDATE_NOTIFICATION
  }

  MOBILE_TWITTER_RESPONSE_CODES = {
    :tkt_err_save => 1,
    :cannot_create_fd_item => 2,
    :ticket_save => 3,
    :not_authorized => 4,
    :reply_failure => 5,
    :reply_success => 6,
    :sandbox_error_msg => 7,
    :cannot_reply => 8,
    :retweet_success => 9,
    :already_retweeted => 10,
    :cannot_retweet => 11,
    :tweeted => 12,
    :social_error_msg => 13,
    :cannot_post => 14,
    :favorite_error => 15,
    :cannot_favorite => 16,
    :favorite_success => 17,
    :unfavorite_success => 18,
    :unfavorite_error => 19,
    :cannot_unfavorite => 20,
    :validation_failed => 21
  }

  MOBILE_TYPE_ANDROID = 0
  MOBILE_TYPE_IOS = 1

  MOBILE_API_RESULT_SHA_FAIL=0
  MOBILE_API_RESULT_SUCCESS=1
  MOBILE_API_RESULT_UNSUPPORTED=2
  MOBILE_API_RESULT_PARAM_FAILED=3

end
