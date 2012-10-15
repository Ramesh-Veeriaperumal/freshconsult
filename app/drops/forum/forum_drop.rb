class Forum::ForumDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :name << :description
  
  def initialize(source)
    super source
  end
  
  def id
    source.id
  end
  
  def type
    source.forum_type
  end

  # This is mainly used to hide "Start a topic button" in announcements forums
  # Can be extended to be used if we are giving permissions to users
  def users_can_start_topic
    !source.announcement?
  end
  
  def visibility
    source.forum_visibility
  end
  
  def type_name
    source.type_name.downcase
  end

  def url
    support_discussions_forum_path(source)
  end

  def create_topic_url
    new_support_discussions_forum_topic_path(source)
  end

  def forum_category
    source.forum_category
  end
  
  def topics
    @topics ||= liquify(*@source.recent_topics)
  end
  
end