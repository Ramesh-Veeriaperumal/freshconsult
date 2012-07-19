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

  def has_comments
  	(source.posts_count > 1) ? true : false
  end

  def last_post
  	source.last_post
  end
  
  def url
  	support_discussions_topic_path(source)
  end

  def id
    source.id
  end
  
end