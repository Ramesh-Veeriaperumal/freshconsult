module Facebook
  module Constants
    
    ITEM_LIST         = ["status", "post", "comment", "reply_to_comment", "photo", "video", "share", "link"]
  
    AUXILLARY_LIST    = ["like"]
    
    ITEM_ACTIONS      = {
        "add"    => ITEM_LIST,
        "remove" => AUXILLARY_LIST
      }
    
    FEED_TYPES = ["post", "status", "comment", "reply_to_comment", "photo", "video", "share", "link", "like", "message"]
    
    POST_TYPE  = Hash[*FEED_TYPES.map{|type| [type, type]}.flatten].symbolize_keys
    
    DEFAULT_KEYWORDS = ["support", "ticket", "issue", "fail", "problem", "suck", "order", "return", "refund"]

    #Stream and Ticket Rule type
    FB_STREAM_TYPE = {
      :default => "Wall",
      :dm      => "DM"
    }
  
    POST_TYPE_CODE = {
      :post               => 1,
      :comment            => 2,
      :reply_to_comment   => 3
      
    }
    
    RULE_TYPE = {
      :strict   => 1,
      :optimal  => 2,
      :broad    => 3,
      :dm       => 4
    }
    
    FETCH_FIELDS = {
      :post     => ["id", "type", "from", "message", "description", "created_time", "link", "picture", "name", "object_id", "story", "likes"],
      :comments => ["id", "from", "can_comment", "created_time", "message", "parent", "attachment", "object"],
      :message  => ["id","from","message","created_time","attachments","shares"],
      :profile_name => ["first_name", "last_name"]
    }
      
    POST_FIELDS                 = FETCH_FIELDS[:post].join(',')
    
    COMMENT_FIELDS              = FETCH_FIELDS[:comments].join(',')

    MESSAGE_FIELDS              = FETCH_FIELDS[:message].join(',') #Used while fetching object of a message got through webhook
    
    DM_FIELDS                   = "messages.fields(id, message, from, created_time, attachments, shares)" #Used while fetching all messages of a page for non realtime enabled
    
    PROFILE_NAME_FIELDS         = FETCH_FIELDS[:profile_name].join(',')

    HASH_KEY_DELIMITER          = "::"

    MESSAGE_THREAD_ID_DELIMITER = "::"

    FACEBOOK_GRAPH_URL          = "https://graph.facebook.com"

    GRAPH_API_VERSION           = "v2.6"

    FB_MESSAGE_PREFIX           = "m_"

    REALTIME_MESSSAGING_CHARACTER_LIMIT = 640
    
  end
end
  
