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
  
  def type_name
    source.type_name.downcase
  end

  def url
    support_discussions_forum_path(source)
  end
  
  def topics
    @topics ||= liquify(*@source.topics)
  end
  
end