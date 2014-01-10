module Social::Twitter::Constants

  TAG_PREFIX = "S"

  MSG_COUNT_FOR_UPDATING_REDIS = 15

  GNIP_DISCONNECT_LIST = "gnip_disconnect"

  #Stream and Ticket Rule type
  STREAM_TYPE = {
    :default => "Default",
    :custom => "Custom"
  }

  # time in sec
  TIME = {
    :max_time_in_sqs => 240,
    :reconnect_timeout => 30,
    :replay_stream_wait_time => 1800
  }

  DYNAMO_KEYS = {
    "feeds" => ["body", "retweetCount", {"gnip" => ["matching_rules"]},
                {"actor" => ["preferredUsername", "image", "id"]}, "verb",
                "postedTime", "id", {"inReplyTo" => ["link"]}
                ],
    "conversations" => ["body", "id"]
  }

end
