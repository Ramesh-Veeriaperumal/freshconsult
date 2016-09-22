module Social::Constants
  
  SOURCE = {
      :twitter  => "Twitter",
      :facebook => "Facebook"
    }

  GNIP_RULE_STATES = [
    [:none,       "Not present in either Production or Replay", 0],
    [:production, "Present only in production",                 1],
    [:replay,     "Present only in Replay",                     2],
    [:both,       "Present both in Production and Replay",      3]
  ]

  GNIP_RULE_STATES_KEYS_BY_TOKEN = Hash[*GNIP_RULE_STATES.map { |i| [i[0], i[2]] }.flatten]

  TICKET_RULE_TYPE = [
    [:default,  "Default ticket rule for the stream", 1],
    [:custom,   "Custom ticket rule for the stream",  2]
  ]

  TICKET_RULE_TYPE_KEYS_BY_TOKEN = Hash[*TICKET_RULE_TYPE.map{ |i| [i[0], i[2]] }.flatten]

  STREAM_FEEDS_ACTION = [
    [:index,      "Initial Call",     0],
    [:show_old,   "Show old feeds",   1],
    [:fetch_new,  "Fetch new feeds",  2]
  ]

  STREAM_FEEDS_ACTION_KEYS = Hash[*STREAM_FEEDS_ACTION.map{ |i| [i[0], i[2]] }.flatten]

  NUM_RECORDS_TO_DISPLAY = 15

  RECENT_SEARCHES_COUNT = 5

  SEARCH_TYPE = {
    :live   => "live_search",
    :saved  => "streams",
    :custom => "custom_search"
  }

  DYNAMO_ACTIONS = {
    :add    => "ADD",
    :put    => "PUT",
    :delete => "DELETE"
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
    },
    
    "unprocessed_feed" =>{
      :name => "social_unprocessed_feed",
      :schema => {
        :hash => {
          :attribute_name => "page_id",
          :attribute_type => "N"
        },
        :range => {
          :attribute_name => "timestamp",
          :attribute_type => "N"
        }
      },
      :retention_period  => 7.days,
      :db_reference_date => "2010-10-13 00:00:00 UTC"
    },
  }

  TABLE_NAME = Hash[*TABLES.keys.map{|i| [i, i]}.flatten]

  DYNAMO_KEYS = {
    "Twitter" => {
      "feeds" => ["body", "retweetCount", {"gnip" => ["matching_rules", "klout_score"]},
                  {"actor" => ["preferredUsername", "image", "id", "displayName"]}, "verb",
                  "postedTime", "id", {"inReplyTo" => ["link"]}, { "twitter_entities" => ["user_mentions"] }
                  ],
      "interactions" => ["id"]
    },
    "Facebook" => {
      "feeds"        => ["feed_id", "requester", "description", "created_at", "object_link", "object_message", "original_post_id"],
      "interactions" => ["id"]
    }
  }
  
  NUMERIC_KEYS = ["likes", "comments_count", "shares"]

  TWITTER_TIMEOUT = {
    :search => 5,
    :dm     => 10,
    :reply  => 10
  }

  STREAM_VOLUME_RETENION_PERIOD = 28.days
  
  MAX_FEEDS_THRESHOLD = 700

  URL_REGEX = /(([a-z]{3,6}:\/\/)|(^|))([a-zA-Z0-9\-]+\.)+[a-z]{2,13}[\.\?\=\&\%\/\w\-\:\#\+\|\*\!]*([^@\s]|$)/
  
  #Length+1 used in nobelcount.js for the manipulation of character count in UI
  TWITTER_URL_LENGTH = " " * 23

  INLINE_IMAGE_HTML_ELEMENT = "<img src=\"%s\" class=\"inline-image\"/>"

end
