# encoding: utf-8
class Forum::TopicDrop < BaseDrop
  
  include Rails.application.routes.url_helpers
  
  self.liquid_attributes += [:title, :posts_count, :merged_topic_id]

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

  def views
    source.hits
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
    @first_post ||= published_posts.first
  end
  
  def last_post
  	source.last_post
  end

  # Useful for showing the latest comment in the topic
  def last_post_url
    "#{support_discussions_topic_path(source)}/page/last#post-#{source.last_post_id}"
  end

  def posts
    ordered_posts.filter(@per_page, page_number)
  end

  def ordered_posts
    unless (sort_by and Post::SORT_ORDER[sort_by.to_sym]).nil?
      published_posts.reorder(Post::SORT_ORDER[sort_by.to_sym])
    else
      published_posts
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

  def merged?
  	source.merged_topic_id.present?
  end

  def parent
    portal_account.topics.find(source.merged_topic_id)
  end

  def merged_topics
    @merged_topics ||= source.merged_topics
  end

  def has_merged_topics?
    merged_topics.present?
  end

  def merged_into
    @merged_into ||= source.merged_into
  end

  def merged_topic_url
    support_discussions_topic_path(source.merged_topic_id)
  end

  def topic_url
    support_discussions_topic_path(source.id)
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
    # Edits have been disallowed.
    # This method only for backward compatibility
    support_discussions_topic_path(source.id)
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

  def cloud_files
    source.posts.first.cloud_files
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

  def followed_by_current_user?
    portal_user.present? && !source.monitorships.active_monitors.by_user(portal_user).count.zero?
  end

  def sort_by
    source.sort_by
  end

  def user_votes
    source.votes
  end

  def comment_count
    @comment_count ||= [source.posts_count - 1, 0].max
  end

  def voters
    @source.voters
  end
  
  private

    def published_posts
      if portal_user
        source.posts.published_and_mine(portal_user)
      else
        source.posts.published
      end
    end

    def page_number
      return nil unless @page
      max_page = [(source.posts_count.to_f / @per_page).ceil.to_i, 1].max 
      return max_page if @page == "last" or @page.to_i > max_page
      return 1 if @page.to_i.to_s != @page #Other invalid strings
      return 1 if @page.to_i <= 0 #Other invalid numbers
      @page
    end

end