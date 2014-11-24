module Facebook::Constants

  #Stream and Ticket Rule type
  STREAM_TYPE = {
    :default => "Wall",
    :dm      => "DM"
  }
  
  POST_TYPE = {
    :post             => "post",
    :status           => "status",
    :comment          => "comment",
    :reply_to_comment => "reply_to_comment"
  }
  
  POST_TYPE_CODE = {
    46  => "status",
    56  => "post",
    247 => "photo",
    128 => "video"
  }
  
  COMMENT_FIELDS = "id, from, can_comment, created_time, message, parent, attachment"
  
  POST_FIELDS = "id, type, from, message, description, created_time, link, picture, name"  
end
