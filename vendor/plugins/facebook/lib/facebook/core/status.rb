class Facebook::Core::Status < Facebook::Core::Post

  def initialize(fan_page)
    super(fan_page)
  end

  def add(feed)
    if feed.post_id
      return if @account.facebook_posts.find_by_post_id(feed.post_id)
      @koala_post.fetch(feed.post_id)
      add_as_ticket if @koala_post.create_ticket
    end
  end

end
