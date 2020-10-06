module Facebook
  module Constants
    STANDARD_TIMEOUT = { request: { timeout: 5, open_timeout: 5 } }

    ITEM_LIST         = ['status', 'post', 'comment', 'reply_to_comment', 'photo', 'video', 'share', 'link'].freeze

    AUXILLARY_LIST    = ['like'].freeze

    ITEM_ACTIONS      = {
      'add' => ITEM_LIST,
      'remove' => AUXILLARY_LIST
    }.freeze

    FEED_TYPES = ['post', 'status', 'comment', 'reply_to_comment', 'photo', 'video', 'share', 'link', 'like', 'message', 'video_inline', 'animated_image_video'].freeze

    POST_TYPE  = Hash[*FEED_TYPES.map { |type| [type, type] }.flatten].symbolize_keys

    DEFAULT_KEYWORDS = ['support', 'ticket', 'issue', 'fail', 'problem', 'suck', 'order', 'return', 'refund'].freeze

    # Stream and Ticket Rule type
    FB_STREAM_TYPE = {
      default: 'Wall',
      dm: 'DM',
      ad_post: 'Ad_post'
    }.freeze

    POST_TYPE_CODE = {
      post: 1,
      comment: 2,
      reply_to_comment: 3
    }.freeze

    CODE_TO_POST_TYPE = Hash[*POST_TYPE_CODE.keys.map { |type| [POST_TYPE_CODE[type], type.to_s] }.flatten]

    RULE_TYPE = {
      strict: 1,
      optimal: 2,
      broad: 3,
      dm: 4,
      ad_post: 5
    }.freeze

    FETCH_FIELDS = {
      post: ['id', 'type', 'from', 'message', 'description', 'created_time', 'link', 'picture', 'name', 'object_id', 'story', 'likes'],
      comments: ['id', 'from', 'can_comment', 'created_time', 'message', 'parent', 'attachment', 'object'],

      message: ['id', 'from', 'to', 'message', 'created_time', 'attachments.fields(id,image_data,mime_type,name,size,video_data,file_url.fields(mime_type,name,id,size))', 'shares.fields(description,id,link,name)'],
      profile_name: ['first_name', 'last_name']
    }.freeze

    POST_FIELDS                 = FETCH_FIELDS[:post].join(',')

    COMMENT_FIELDS              = FETCH_FIELDS[:comments].join(',')

    MESSAGE_FIELDS              = FETCH_FIELDS[:message].join(',') # Used while fetching object of a message got through webhook

    DM_FIELDS                   = 'updated_time,messages.limit(25).fields(id,message,from,created_time,attachments.fields(id,image_data,mime_type,name,size,video_data,file_url.fields(mime_type,name,id,size)),shares.fields(description,id,link,name))'.freeze # Used while fetching all messages of a page for non realtime enabled

    PROFILE_NAME_FIELDS         = FETCH_FIELDS[:profile_name].join(',')

    HASH_KEY_DELIMITER          = '::'.freeze

    MESSAGE_THREAD_ID_DELIMITER = '::'.freeze

    FACEBOOK_GRAPH_URL          = 'https://graph.facebook.com'.freeze

    LIMIT_PER_REQUEST           = 100

    GRAPH_API_VERSION           = 'v3.2'.freeze

    FB_MESSAGE_PREFIX           = 'm_'.freeze

    REALTIME_MESSSAGING_CHARACTER_LIMIT = 640

    URL_DELIMITER               = '?'.freeze

    FILENAME_DELIMITER          = '.'.freeze

    URL_PATH_DELIMITER          = '/'.freeze

    # https://developers.facebook.com/docs/messenger-platform/send-messages/message-tags
    MESSAGE_TAG                 = 'ISSUE_RESOLUTION'.freeze
    MESSAGE_TYPE                = 'MESSAGE_TAG'.freeze

    URL_PATHS = {
      message: {
        image: :image_data,
        video: :video_data
      }
    }.freeze

    FEED_VIDEO      = '<div class="facebook_post"><a class="thumbnail" href="%{target_url}" target="_blank"><img src="%{thumbnail}"></a><div><p><a href="%{att_url}}" target="_blank"> %{name}</a></p><p><strong>%{html_content}</strong></p><p>%{desc}</p></div></div>'.freeze

    FEED_PHOTO      = '<div class="facebook_post"><p> %{html_content}</p><p><a href="%{link}" target="_blank"><img height="%{height}" src="%{photo_url}"></a></p></div>'.freeze

    FEED_LINK       = '<div class="facebook_post"><p> %{html_content}</p><p>%{link_story}</p></div>'.freeze

    FEED_VIDEO_WITH_ORIGINAL_POST = "
    <div class=\"fb-original-post__image\">
      <a class=\"thumbnail\" href=\"%{target_url}\" target=\"_blank\">
        <img src=\"%{thumbnail}\">
      </a>
    </div>
    <div class=\"fb-original-post__description\">
        <h2 class=\"subject fb-original-post__title\">%{page_name}</h2>
        <p class=\"fb-original-post__post\">%{html_content}</p>
    </div>".freeze

    FEED_PHOTO_WITH_ORIGINAL_POST = "
    <div class=\"fb-original-post__image\">
      <a href=\"%{link}\" target=\"_blank\">
        <img src=\"%{photo_url}\">
      </a>
    </div>
    <div class=\"fb-original-post__description\">
        <h2 class=\"subject fb-original-post__title\">%{page_name}</h2>
        <p class=\"fb-original-post__post\">%{html_content}</p>
    </div>".freeze

    FEED_LINK_WITH_ORIGINAL_POST = "
    <div class=\"fb-original-post__description\">
        <h2 class=\"subject fb-original-post__title\">%{page_name}</h2>
        <p class=\"fb-original-post__post\">%{html_content}</p>
        %{link_story}
    </div>".freeze

    FEED_WITH_ORIGINAL_POST = "
    <div class=\"fb-original-post__description\">
        <h2 class=\"subject fb-original-post__title\">%{page_name}</h2>
        <p class=\"fb-original-post__post\">%{html_content}</p>
    </div>".freeze

    COMMENT_WITH_ORIGINAL_POST = '<div class="facebook_post"><p>%{comment}</p><div class="fb-original-post">%{original_post}</div></div>'.freeze

    COMMENT_SHARE   = FEED_LINK

    COMMENT_PHOTO   = FEED_PHOTO

    COMMENT_PHOTO_WITH_ORIGINAL_POST = '<div class="facebook_post"><p> %{html_content}</p><p><a href="%{link}" target="_blank"><img height="%{height}" src="%{photo_url}"></a></p><div class="fb-original-post">%{original_post}</div></div>'.freeze

    COMMENT_STICKER = FEED_PHOTO

    MESSAGE_IMAGE   = '%{html_content} <a href="%{url}" target="_blank"><img src="%{url}" height="%{height}"></a>'.freeze

    MESSAGE_SHARE   = MESSAGE_IMAGE # {}"%{html_content} <a href=\"%{url}\" target=\"_blank\"> %{name} </a>"

    LINK_SHARE      = '%{html_content} <p>%{title}</p><a href="%{url}" target="_blank"> %{url} </a>'.freeze

    TEXT_SHARE = '%{html_content} <p><b>%{name} : </b>%{value}</p><br>'.freeze

    ACCESS_TOKEN_PATH = 'oauth/access_token'.freeze

    ACCESS_TOKEN_PARAMS = 'client_id=%{client_id}&client_secret=%{client_secret}&redirect_uri=%{redirect_uri}&code=%{code}'.freeze

    INLINE_FILE_FORMATS = ['png', 'jpeg', 'gif', 'tiff'].freeze

    PARENT_POST_LENGTH = 230

    MESSAGE_UPDATED_AT = 'updated_time'.freeze

    FB_MSG_TYPES = ['dm', 'post', 'ad_post'].freeze

    DEFAULT_MESSAGE_LIMIT = 25

    FB_API_ME = 'me'.freeze

    FB_API_CONVERSATIONS = 'conversations'.freeze

    FB_API_MESSAGES = 'messages'.freeze

    FB_THREAD_DEFAULT_API_OPTIONS = { fields: DM_FIELDS, limit: DEFAULT_MESSAGE_LIMIT, request: { timeout: 10, open_timeout: 10 } }.freeze

    FB_DM_DEFAULT_API_OPTIONS = { fields: MESSAGE_FIELDS, limit: DEFAULT_MESSAGE_LIMIT, request: { timeout: 10, open_timeout: 10 } }.freeze

    FB_API_HTTP_COMPONENT = { http_component: 'body' }.freeze

    DEFAULT_PAGE_LIMIT = 9 # Restrict the next page fetch logic to maximum of 9 pages apart from the first page fetched. So for a facebook page, only 10 pages with the limit of 25 threads and messages on each call will be fetched.

    FB_WEBHOOK_EVENTS = 'feed,messages,message_echoes'.freeze

    VALID_ATTACHMENTS_WHEN_FILTER_MENTIONS_ENABLED = ['photo', 'video_inline'].freeze
  end
end
