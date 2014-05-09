module Social::Constants

  GNIP_RULE_STATES = [
    [:none, "Not present in either Production or Replay", 0],
    [:production, "Present only in production", 1],
    [:replay, "Present only in Replay", 2],
    [:both, "Present both in Production and Replay", 3]
  ]

  GNIP_RULE_STATES_KEYS_BY_TOKEN = Hash[*GNIP_RULE_STATES.map { |i| [i[0], i[2]] }.flatten]

  TICKET_RULE_TYPE = [
    [:default, "Default ticket rule for the stream", 1],
    [:custom, "Custom ticket rule for the stream", 2]
  ]

  TICKET_RULE_TYPE_KEYS_BY_TOKEN = Hash[*TICKET_RULE_TYPE.map{ |i| [i[0], i[2]] }.flatten]

  STREAM_FEEDS_ACTION = [
    [:old, "Show old tweets", 0],
    [:new, "Fetch new tweets", 1]
  ]

  STREAM_FEEDS_ACTION_KEYS = Hash[*STREAM_FEEDS_ACTION.map{ |i| [i[0], i[2]] }.flatten]

  NUM_RECORDS_TO_DISPLAY = 15

  RECENT_SEARCHES_COUNT = 5

  SEARCH_TYPE = {
    :live   => "live_search",
    :saved  => "streams",
    :custom => "custom_search"
  }

  TABLES = {
    "feeds" => {
      :name => "fd_social_feeds",
      :schema => {
        :hash => {
          :attribute_name => "stream_id",
          :attribute_type => "S"
        },
        :range => {
          :attribute_name => "feed_id",
          :attribute_type => "S"
        }
      },
      :retention_period  => 7.days,
      :db_reference_date => "2010-10-13 00:00:00 UTC"
    },

    "interactions" => {
      :name => "fd_social_interactions",
      :schema => {
        :hash => {
          :attribute_name => "stream_id",
          :attribute_type => "S"
        },
        :range => {
          :attribute_name => "object_id",
          :attribute_type => "S"
        }
      },
      :retention_period  => 7.days,
      :db_reference_date => "2010-10-13 00:00:00 UTC"
    }
  }

  DYNAMO_KEYS = {
    "Twitter" => {
      "feeds" => ["body", "retweetCount", {"gnip" => ["matching_rules", "klout_score"]},
                  {"actor" => ["preferredUsername", "image", "id", "displayName"]}, "verb",
                  "postedTime", "id", {"inReplyTo" => ["link"]}, { "twitter_entities" => ["user_mentions"] }
                  ],
      "interactions" => ["id"]
    },
    "Facebook" => {
      "feeds"         => ["id", "type", "from", "message", "created_time", "can_comment", "parent"],
      "interactions" => nil
    }
  }

  STREAM_VOLUME_RETENION_PERIOD = 28.days

end