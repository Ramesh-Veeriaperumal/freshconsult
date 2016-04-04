module Facebook
  module Constants
    
    ITEM_LIST         = ["status", "post", "comment", "reply_to_comment", "photo", "video", "share", "link", "like"]
  
    AUXILLARY_LIST    = ["like"]
    
    ITEM_ACTIONS      = {
        "add"    => ITEM_LIST,
        "remove" => AUXILLARY_LIST
      }
    
    FEED_TYPES = ["post", "status", "comment", "reply_to_comment", "photo", "video", "share", "link", "like", "message"]
    
    POST_TYPE  = Hash[*FEED_TYPES.map{|type| [type, type]}.flatten].symbolize_keys

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
      :comments => ["id", "from", "can_comment", "created_time", "message", "parent", "attachment", "object"]
    }
      
    POST_FIELDS    = FETCH_FIELDS[:post].join(',')
    
    COMMENT_FIELDS = FETCH_FIELDS[:comments].join(',')
    
    HASH_KEY_DELIMITER = "::"
    
  end
end
  

