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
      :retention_period  => 14.days,
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
      :retention_period  => 14.days,
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
      :retention_period  => 14.days,
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
  
  NUMERIC_KEYS = ["likes", "comments_count", "shares", "smart_filter_response"]

  TWITTER_TIMEOUT = {
    :search => 5,
    :dm     => 10,
    :reply  => 60
  }

  STREAM_VOLUME_RETENION_PERIOD = 28.days
  
  MAX_FEEDS_THRESHOLD = 1500

  URL_REGEX = /(([a-z]{3,6}:\/\/)|(^|))([a-zA-Z0-9\-]+\.)+[a-z]{2,13}[\.\?\=\&\%\/\w\-\:\#\+\|\*\!]*([^@\s]|$)/
  
  #Length+1 used in nobelcount.js for the manipulation of character count in UI
  TWITTER_URL_LENGTH = " " * 23

  INLINE_IMAGE_HTML_ELEMENT = '<div class="image-enlarge-link twitter_image">
                                <img src="%{url}" data-test-src="%{data_test_url}" class="inline-image"></div>'

  TWITTER_IMAGES = '<div class="twitter_media_content"> %{img_content} <div>'

  TWITTER_MEDIA_PHOTO = 'Twitter::Media::Photo'.freeze

  TWITTER_MEDIA_ANIMATED_GIF = 'Twitter::Media::AnimatedGif'.freeze

  WHITELISTED_SPECIAL_CHARS_REGEX = /[,.():;=\-\<\>\/&!?%+"']/

  EMOJI_UNICODE_REGEX = /[\u{1F600}-\u{1F64F}|\u2600-\u26FF|\u{1F300}-\u{1F5FF}|\u{1F900}-\u{1F9FF}|\u{1F680}-\u{1F6FF}|\u2700-\u27BF|\uFE0F|\u200D| \u{1FA70}-\u{1FA7A}| \u{1FA90}| \u2B50| \u{1FA80}-\u{1FA82} | \u{1FA91}-\u{1FA95}| \u2300-\u23FF| \u{1F000}-\u{1FFFF}]/i.freeze

  EMOJI_SPECIAL_CHARS_ARRAY = ['o/', '</3', '<3', '8-D', '8D', ':-D', '=-3', '=-D', '=3', '=D', 'B^D', 'X-D', 'XD', 'x-D', 'xD', ':\')', ':\'-)', ':-))', '8)', ':)', ':-)', ':3', ':D', ':]', ':^)', ':c)', ':o)', ':}', ':っ)', '=)', '=]', '0:)', '0:-)', '0:-3', '0:3', '0;^)', 'O:-)', '3:)', '3:-)', '}:)', '}:-)', '*)', '*-)', ':-, ', ';)', ';-)', ';-]', ';D', ';]', ';^)', ':-|', ':|', ':(', ':-(', ':-<', ':-[', ':-c', ':<', ':[', ':c', ':{', ':っC', '%)', '%-)', ':-P', ':-b', ':-p', ':-Þ', ':-þ', ':P', ':b', ':p', ':Þ', ':þ', ';(', '=p', 'X-P', 'XP', 'd:', 'x-p', 'xp', ':-||', ':@', ':-.', ':-/', ':/', ':L', ':S', ':\\', '=/', '=L', '=\\', ':\'(', ':\'-(', '^5', '^<_<', 'o/\\o', '|-O', '|;-)', ':###..', ':-###..', 'D8', 'D:', 'D:<', 'D;', 'D=', 'DX', 'v.v', '8-0', ':-O', ':-o', ':O', ':o', 'O-O', 'O_O', 'O_o', 'o-o', 'o_O', 'o_o', ':$', '#-)', ':#', ':&', ':-#', ':-&', ':-X', ':X', ':-J', ':*', ':^*', 'ಠ_ಠ', '*\\0/*', '\\o/', ':>', '>.<', '>:(', '>:)', '>:-)', '>:/', '>:O', '>:P', '>:[', '>:\\', '>;)', '>_>^'].freeze

  NEW_LINE_WITH_CARRIAGE_RETURN = /\r\n/
 
  NEW_LINE_CHARACTER = "\n"

  TWITTER_MENTION = "@"
  EU_TWITTER_HANDLES = "eu_twitter_handles"
  TWEET_MEDIA_PHOTO = 'photo'.freeze
  TWEET_MEDIA_ANIMATED_GIF = 'animated_gif'.freeze
  TWEET_ALREADY_EXISTS = "Tweet already converted as a ticket".freeze
  TICKET_ARCHIVED = "Ticket is an archived ticket".freeze

  FACEBOOK_POST_ALREADY_EXISTS = 'Facebook Post already converted to a ticket'.freeze

  TWITTER_FEED_TICKET = 'twitter_feed_ticket'.freeze

  TWITTER_ERROR_CODES = {
    reauth_required: 89,
    timeout: 504,
    archived_ticket_error: 406
  }
end
