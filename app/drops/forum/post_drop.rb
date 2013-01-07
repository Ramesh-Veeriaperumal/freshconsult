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

  def topic
    source.topic
  end

  def answer?
    source.answer
  end

  def attachments
    source.attachments
  end

  def url
    support_discussions_topic_path(source.topic, :anchor => "post-#{source.id}")
  end

  def edit_url
    edit_support_discussions_topic_post_path(source.topic, source.id)
  end

  def delete_url
    support_discussions_topic_post_path(source.topic, source.id)
  end
  
end