module Facebook
  module Constants
    
    ITEM_LIST         = ["status", "post", "comment", "reply_to_comment", "photo", "video", "share", "link"]
  
    AUXILLARY_LIST    = ["like"]
    
    ITEM_ACTIONS      = {
        "add"    => ITEM_LIST,
        "remove" => AUXILLARY_LIST
      }
    
    FEED_TYPES = ["post", "status", "comment", "reply_to_comment", "photo", "video", "share", "link", "like", "message", "video_inline", "animated_image_video"]
    
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

    CODE_TO_POST_TYPE = Hash[*POST_TYPE_CODE.keys.map{|type| [POST_TYPE_CODE[type], type.to_s]}.flatten]
    
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
    
    DM_FIELDS                   = "messages.fields(id,message,from,created_time,attachments.fields(id,image_data,mime_type,name,size,video_data,file_url.fields(mime_type,name,id,size)),shares.fields(description,id,link,name))" #Used while fetching all messages of a page for non realtime enabled
    
    PROFILE_NAME_FIELDS         = FETCH_FIELDS[:profile_name].join(',')

    HASH_KEY_DELIMITER          = "::"

    MESSAGE_THREAD_ID_DELIMITER = "::"

    FACEBOOK_GRAPH_URL          = "https://graph.facebook.com"

    LIMIT_PER_REQUEST           = 100

    GRAPH_API_VERSION           = "v2.11"

    FB_MESSAGE_PREFIX           = "m_"

    REALTIME_MESSSAGING_CHARACTER_LIMIT = 640

    URL_DELIMITER               = "?"

    FILENAME_DELIMITER          = "."

    URL_PATH_DELIMITER          = "/"

    #https://developers.facebook.com/docs/messenger-platform/send-messages/message-tags
    MESSAGE_TAG                 = "ISSUE_RESOLUTION" 
    MESSAGE_TYPE                = "MESSAGE_TAG"

    URL_PATHS = {
      :message => {
        :image => :image_data,
        :video => :video_data
      }
    }


    FEED_VIDEO      = "<div class=\"facebook_post\"><a class=\"thumbnail\" href=\"%{target_url}\" target=\"_blank\"><img src=\"%{thumbnail}\"></a><div><p><a href=\"%{att_url}}\" target=\"_blank\"> %{name}</a></p><p><strong>%{html_content}</strong></p><p>%{desc}</p></div></div>"

    FEED_PHOTO      = "<div class=\"facebook_post\"><p> %{html_content}</p><p><a href=\"%{link}\" target=\"_blank\"><img height=\"%{height}\" src=\"%{photo_url}\"></a></p></div>"

    FEED_LINK       = "<div class=\"facebook_post\"><p> %{html_content}</p><p>%{link_story}</p></div>"

    FEED_VIDEO_WITH_ORIGINAL_POST	= "
    <div class=\"fb-original-post__image\">
      <a class=\"thumbnail\" href=\"%{target_url}\" target=\"_blank\">
        <img src=\"%{thumbnail}\">
      </a>
    </div>
    <div class=\"fb-original-post__description\"> 
        <h2 class=\"subject fb-original-post__title\">%{page_name}</h2> 
        <p class=\"fb-original-post__post\">%{html_content}</p>
    </div>"

    FEED_PHOTO_WITH_ORIGINAL_POST	= "
    <div class=\"fb-original-post__image\">
      <a href=\"%{link}\" target=\"_blank\">
        <img src=\"%{photo_url}\">
      </a>
    </div>
    <div class=\"fb-original-post__description\"> 
        <h2 class=\"subject fb-original-post__title\">%{page_name}</h2> 
        <p class=\"fb-original-post__post\">%{html_content}</p>
    </div>"

    FEED_LINK_WITH_ORIGINAL_POST	= "
    <div class=\"fb-original-post__description\"> 
        <h2 class=\"subject fb-original-post__title\">%{page_name}</h2> 
        <p class=\"fb-original-post__post\">%{html_content}</p>
        %{link_story}
    </div>"

    FEED_WITH_ORIGINAL_POST       = "
    <div class=\"fb-original-post__description\"> 
        <h2 class=\"subject fb-original-post__title\">%{page_name}</h2> 
        <p class=\"fb-original-post__post\">%{html_content}</p>
    </div>"

    COMMENT_WITH_ORIGINAL_POST = "<div class=\"facebook_post\"><p>%{comment}</p><div class=\"fb-original-post\">%{original_post}</div></div>"

    COMMENT_SHARE   = FEED_LINK

    COMMENT_PHOTO   = FEED_PHOTO

    COMMENT_PHOTO_WITH_ORIGINAL_POST = "<div class=\"facebook_post\"><p> %{html_content}</p><p><a href=\"%{link}\" target=\"_blank\"><img height=\"%{height}\" src=\"%{photo_url}\"></a></p><div class=\"fb-original-post\">%{original_post}</div></div>"

    COMMENT_STICKER = FEED_PHOTO

    MESSAGE_IMAGE   = "%{html_content} <a href=\"%{url}\" target=\"_blank\"><img src=\"%{url}\" height=\"%{height}\"></a>"

    MESSAGE_SHARE   = MESSAGE_IMAGE#{}"%{html_content} <a href=\"%{url}\" target=\"_blank\"> %{name} </a>"

    LINK_SHARE      = "%{html_content} <p>%{title}</p><a href=\"%{url}\" target=\"_blank\"> %{url} </a>"

    ACCESS_TOKEN_PATH = "oauth/access_token"

    ACCESS_TOKEN_PARAMS = "client_id=%{client_id}&client_secret=%{client_secret}&redirect_uri=%{redirect_uri}&code=%{code}"

    INLINE_FILE_FORMATS = ['png', 'jpeg', 'gif', 'tiff']

    PARENT_POST_LENGTH = 230

    PAGE_SCOPE_URL = "pages_id_mapping"

  end
end
  
