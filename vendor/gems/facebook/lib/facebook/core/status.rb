class Facebook::Core::Status < Facebook::Core::Post
  
  def initialize(fan_page, koala_post)
    super(fan_page, koala_post)
    @type = POST_TYPE[:status]
  end

  def add(feed)
    @feed = feed
    if feed.post_id
      return if @account.facebook_posts.find_by_post_id(feed.post_id)
      process
    end
  end
  
end
