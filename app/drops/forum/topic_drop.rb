class Forum::TopicDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :title 
  
  def initialize(source)
    super source
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

  def created_on
    source.created_at.to_s(:long_day)
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
  
end