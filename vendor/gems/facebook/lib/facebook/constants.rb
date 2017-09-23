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
      :message  => ["id","from","message","created_time","attachments.fields(id,image_data,mime_type,name,size,video_data,file_url.fields(mime_type,name,id,size))","shares.fields(description,id,link,name)"],
      :profile_name => ["first_name", "last_name"]
    }
      
    POST_FIELDS                 = FETCH_FIELDS[:post].join(',')
    
    COMMENT_FIELDS              = FETCH_FIELDS[:comments].join(',')

    MESSAGE_FIELDS              = FETCH_FIELDS[:message].join(',') #Used while fetching object of a message got through webhook
    
    DM_FIELDS                   = "thread_key,messages.fields(id,message,from,created_time,attachments.fields(id,image_data,mime_type,name,size,video_data,file_url.fields(mime_type,name,id,size)),shares.fields(description,id,link,name))" #Used while fetching all messages of a page for non realtime enabled
    
    PROFILE_NAME_FIELDS         = FETCH_FIELDS[:profile_name].join(',')

    HASH_KEY_DELIMITER          = "::"

    MESSAGE_THREAD_ID_DELIMITER = "::"

    FACEBOOK_GRAPH_URL          = "https://graph.facebook.com"

    GRAPH_API_VERSION           = "v2.6"

    FB_MESSAGE_PREFIX           = "m_"

    REALTIME_MESSSAGING_CHARACTER_LIMIT = 640

    URL_DELIMITER               = "?"

    FILENAME_DELIMITER          = "."

    URL_PATH_DELIMITER          = "/"

    URL_PATHS = {
      :message => {
        :image => :image_data,
        :video => :video_data
      }
    }

    FEED_VIDEO      = "<div class=\"facebook_post\"><a class=\"thumbnail\" href=\"%{target_url}\" target=\"_blank\"><img src=\"%{thumbnail}\"></a><div><p><a href=\"%{att_url}}\" target=\"_blank\"> %{name}</a></p><p><strong>%{html_content}</strong></p><p>%{desc}</p></div></div>"

    FEED_PHOTO      = "<div class=\"facebook_post\"><p> %{html_content}</p><p><a href=\"%{link}\" target=\"_blank\"><img height=\"%{height}\" src=\"%{photo_url}\"></a></p></div>"

    FEED_LINK       = "<div class=\"facebook_post\"><p> %{html_content}</p><p>%{link_story}</p></div>"

    COMMENT_SHARE   = FEED_LINK

    COMMENT_PHOTO   = FEED_PHOTO

    COMMENT_STICKER = FEED_PHOTO

    MESSAGE_IMAGE   = "%{html_content} <a href=\"%{url}\" target=\"_blank\"><img src=\"%{url}\" height=\"%{height}\"></a>"

    MESSAGE_SHARE   = MESSAGE_IMAGE#{}"%{html_content} <a href=\"%{url}\" target=\"_blank\"> %{name} </a>"

    ACCESS_TOKEN_PATH = "oauth/access_token"

    ACCESS_TOKEN_PARAMS = "client_id=%{client_id}&client_secret=%{client_secret}&redirect_uri=%{redirect_uri}&code=%{code}"

    INLINE_FILE_FORMATS = ['png', 'jpeg', 'gif', 'tiff']

  end
end
  
