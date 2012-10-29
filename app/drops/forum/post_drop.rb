class Forum::PostDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :body << :body_html
  
  def initialize(source)
    super source
  end

  def id
    source.id
  end

  def created_on
    source.created_at
  end

  def user
  	source.user
  end

  def url
    support_discussions_topic_path(source.topic, :anchor => "post-#{source.id}")
  end

  def attachments
    source.attachments
  end
  
end