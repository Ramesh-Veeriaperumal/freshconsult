class Forum::TopicDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :title
  
  def initialize(source)
    super source
  end
  
  def id
    source.id
  end
  
end