class Forum::TopicDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :title 

  def context=(current_context)    
    current_context['paginate_url'] = support_discussions_topic_path(source)

    super
  end
  
  def initialize(source)
    super source
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

  # Stamp key for the topic (planned, inprogress, deferred, implemented, nottaken)
  def stamp
    source.stamp_key
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

  def last_post_url
    source.last_post_url
  end

  def posts
    source.posts.filter(@per_page, @page)
  end

  def id
    source.id
  end

  def url
  	support_discussions_topic_path(source)
  end

  def forum
    source.forum
  end

  def voted_by_current_user
    source.voted_by_user? portal_user
  end

  def like_url
    like_support_discussions_topic_path(source)
  end

  def unlike_url
    unlike_support_discussions_topic_path(source)
  end

  def edit_url
    edit_support_discussions_topic_path(source)
  end

  def toggle_follow_url
    toggle_monitor_support_discussions_topic_path(source)
  end

  def attachments
    source.posts.first.attachments
  end

  # To check if this is a new topic page of edit page
  def exits?
    source.new_record?
  end
    
  def locked?
    source.locked?
  end

  def sticky?
    source.sticky?
  end
  
  def answered?
    source.answered?
  end
  # !PORTALCSS CHECK need to check with shan 
  # if we can keep excerpts for individual model objects
  def excerpt_title
    source.excerpts.title
  end

  def excerpt_description
    source.posts.first.body.gsub(/<\/?[^>]*>/, "")
  end

end