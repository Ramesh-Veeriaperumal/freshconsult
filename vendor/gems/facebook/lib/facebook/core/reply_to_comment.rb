class Facebook::Core::ReplyToComment < Facebook::Core::Comment
  
  include Facebook::Constants 

  def initialize(fan_page, koala_comment)
    super(fan_page, koala_comment)
    @type = POST_TYPE[:reply_to_comment]
  end

  def add(feed)
    @feed       = feed
    @comment_id = feed.comment_id
    process
  end

  def process(koala_comment = nil)
    @koala_comment = koala_comment.nil? ? @koala_comment : koala_comment
    return if feed_converted?(@koala_post.feed_id)
    
    comment_ticket = @account.facebook_posts.find_by_post_id(@koala_comment.parent[:id])   
    post_ticket    = @account.facebook_posts.find_by_post_id(@koala_comment.parent_post)
    
    if comment_ticket && comment_ticket.is_ticket?
      note = add_as_note(comment_ticket.postable, @koala_comment)
    elsif post_ticket && post_ticket.is_ticket?
      add_comment_as_note(post_ticket)
    else
      add_as_post_and_note
    end
  end

  def in_reply_to
    @koala_comment.parent[:id] if koala_comment.parent
  end
  
  def feed_id
    @koala_comment.comment_id
  end
  
  private
    def add_as_post_and_note
      koala_post = parent_post
      type = koala_post.company_post? ? POST_TYPE[:status] : POST_TYPE[:post]
      convert = true if @koala_comment.visitor_post? and @fan_page.import_company_posts
      ("facebook/core/"+"#{type}").camelize.constantize.new(@fan_page, koala_post).process(koala_post, convert)
    end 
    
    def parent_post
      koala_parent_post = Facebook::KoalaWrapper::Post.new(@fan_page)
      koala_parent_post.fetch(koala_comment.parent_post)
      koala_parent_post
    end
  
    def add_comment_as_note(post_ticket)
      parent_comment_id = @koala_comment.parent[:id]
      parent_fb_post = @account.facebook_posts.find_by_post_id(parent_comment_id, :select => :id)
      parent_fb_post.blank? ? fetch_parent_comment : add_as_note(post_ticket.postable, @koala_comment)
    end
  
    def fetch_parent_comment
      koala_parent_comment = Facebook::KoalaWrapper::Comment.new(@fan_page)
      koala_parent_comment.fetch(in_reply_to)
      core_comment = Facebook::Core::Comment.new(@fan_page, koala_parent_comment)
      core_comment.process
    end
end
