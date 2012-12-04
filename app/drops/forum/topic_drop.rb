class Forum::TopicDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :title 
  
  def initialize(source)
    super source
  end

  def render_topic
    default_context.inspect
  end

  def stamp_name
  	source.stamp_name
  end

  def stamp_type
  	source.stamp_type
  end

  def user
  	source.user
  end

  def votes
    source.user_votes
  end

  def created_on
    source.created_at
  end

  def has_comments
  	(source.posts_count > 1) ? true : false
  end

  def first_post
    source.posts.first
  end

  def last_post
  	source.last_post
  end

  def posts
    source.posts
  end
  
  def url
  	support_discussions_topic_path(source)
  end

  def id
    source.id
  end

  def forum
    source.forum
  end

  def voted_by_current_user?
    source.voted_by_user? User.current
  end

  def like_url
    like_support_discussions_topic_path(source)
  end

  def unlike_url
    unlike_support_discussions_topic_path(source)
  end

  def toggle_follow_url
    toggle_monitor_support_discussions_topic_path(source)
  end

  def attachments
    source.posts.first.attachments
  end

  def exits?
    source.new_record?
  end
    
  def locked?
    source.locked?
  end
end