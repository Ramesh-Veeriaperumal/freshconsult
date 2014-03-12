# encoding: utf-8
class Forum::TopicDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :title << :posts_count

  def context=(current_context)    
    current_context['paginate_url'] = support_discussions_topic_path(source) unless source.new_record?

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
    published_posts.first
  end
  
  def last_post
  	source.last_post
  end

  # Useful for showing the latest comment in the topic
  def last_post_url
    "#{support_discussions_topic_path(source)}/page/last#post-#{source.last_post_id}"
  end

  def posts
    unless @per_page.blank?
      # If the page id is last then calculate the number of pages in the topic
      @page = [(source.posts_count.to_f / @per_page).ceil.to_i, 1].max if @page == "last"
      published_posts.filter(@per_page, @page)
    else
      # If the collection is not paginated then fetch all posts
      published_posts.all
    end
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
    published_posts.first.attachments
  end

  def toggle_solution_url
    toggle_solution_support_discussions_topic_path(source)
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
    RAILS_DEFAULT_LOGGER.debug "Checking for answered?"
    source.answered?
  end

  def solved?
    source.solved?
  end

  # This will return a post object
  def best_answer
    source.answer
  end

  # !PORTALCSS CHECK need to check with shan 
  # if we can keep excerpts for individual model objects
  def excerpt_title
    source.excerpts.title
  end

  def excerpt_description
    published_posts.first.body.gsub(/<\/?[^>]*>/, "")
  end

  private

    def published_posts
      if portal_user
        source.posts.published_and_mine(portal_user)
      else
        source.posts.published
      end
    end

end