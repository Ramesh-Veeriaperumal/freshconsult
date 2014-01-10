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
      :retention_period => 7.days,
      :db_reference_date => "2010-10-13 00:00:00 UTC"
    },

    "conversations" => {
      :name => "fd_social_conversations",
      :schema => {
        :hash => {
          :attribute_name => "stream_id",
          :attribute_type => "S"
        },
        :range => {
          :attribute_name => "user_id",
          :attribute_type => "S"
        }
      },
      :retention_period => 7.days,
      :db_reference_date => "2010-10-13 00:00:00 UTC"
    }
  }

end
