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
  
  def visibility
    source.forum_visibility
  end
  
  def url
    category_forum_path(source.forum_category, source)
  end
  
  def topics
    @topics ||= liquify(*@source.topics)
  end
  
end