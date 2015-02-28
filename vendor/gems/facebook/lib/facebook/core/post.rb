class Facebook::Core::Post

  include Facebook::Constants
  include Facebook::Util
  include Facebook::Core::Util

  attr_accessor :fan_page, :account, :koala_post, :source, :type

  def initialize(fan_page, koala_post)
    @account    = fan_page.account
    @fan_page   = fan_page
    @koala_post = koala_post
    @source     = SOURCE[:facebook]
    @type       = POST_TYPE[:post]
  end

  def add(feed)
    @feed = feed
    if feed.post_id
      post_id = feed.post_id
      #hack because facebook doesn't differenciate between status and post
      #Posts give the post id as pageid_postid at most times. Hack is still valid when the result is otherwise
      post_id = feed.page_id + "_" + post_id unless post_id.include?("_")
      return if @account.facebook_posts.find_by_post_id(feed.post_id)
      process(nil, realtime_subscription)
    end
  end

  def process(koala_post = nil, real_time_update = true, convert = false)
    @koala_post = koala_post if koala_post.present?
    return if feed_converted?(@koala_post.feed_id)
    
    convert_post, convert_args = convert_args(@koala_post, convert)
    if convert_post
      ticket = add_as_ticket(@fan_page, @koala_post, real_time_update, convert_args) 
      process_comments if ticket
    end
  end

  def feed_id
    @koala_post.post_id
  end

  def in_reply_to
    nil
  end

  def feed_hash
    @koala_post.post
  end
  

  private
  
  def process_comments
    #Along with the post, create notes for all the available comments
    @koala_post.comments.each do |c|
      comment = koala_comment(c)
      Facebook::Core::Comment.new(@fan_page, comment).process(nil, realtime_subscription)
    end
  end

  def koala_comment(comment)
    koala_comment = Facebook::KoalaWrapper::Comment.new(@fan_page)
    koala_comment.comment = comment
    koala_comment.parse
    koala_comment    
  end

  def realtime_subscription
    fan_page.realtime_subscription
  end 
    
end
