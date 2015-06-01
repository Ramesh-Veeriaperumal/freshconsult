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
    :reply_to_comment => "reply_to_comment",
    :photo            => "photo",
    :video            => "video",
    :share            => "share",
    :link             => "link"
  }
  
  POST_TYPE_CODE = {
    :post               => 1,
    :comment            => 2,
    :reply_to_comment   => 3
    
  }
  
  COMMENT_FIELDS = "id, from, can_comment, created_time, message, parent, attachment"
  
  POST_FIELDS = "id, type, from, message, description, created_time, link, picture, name, object_id, story"  
end
