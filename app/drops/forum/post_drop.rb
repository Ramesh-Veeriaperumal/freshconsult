class Forum::PostDrop < BaseDrop
  
  include Rails.application.routes.url_helpers
  
  self.liquid_attributes += [:body, :body_html]
  
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

  def cloud_files
    source.cloud_files
  end

  def url
    support_discussions_topic_path(source.topic, :anchor => "post-#{source.id}")
  end

  def edit_url
    # Edits have been disallowed.
    # This method only for backward compatibility
    support_discussions_topic_path(source.topic, :anchor => "post-#{source.id}")
  end

  def delete_url
    support_discussions_topic_post_path(source.topic, source.id)
  end

  def toggle_answer_url
    toggle_answer_support_discussions_topic_post_path(source.topic, source.id)
  end

  def user_can_mark_as_answer?
    source.can_mark_as_answer?(portal_user)
  end

  def best_answer_url
    support_discussions_topic_best_answer_path(source.topic, source.id)
  end
  
end