class Facebook::Core::Comment
  
  include Facebook::Core::Util
  include Facebook::KoalaWrapper::ExceptionHandler
  include Social::Dynamo::Facebook
  include Facebook::Constants
  include Facebook::Util
  
  attr_accessor :fan_page, :account, :koala_comment, :source, :type

  def initialize(fan_page, koala_comment)
    @account       = fan_page.account
    @fan_page      = fan_page
    @rest          = Koala::Facebook::API.new(fan_page.page_token)
    @koala_post    = Facebook::KoalaWrapper::Post.new(fan_page)
    @koala_comment = koala_comment
    @source        = SOURCE[:facebook]
    @type          = POST_TYPE[:comment]
  end

  def add(feed)
    @feed = feed
    @comment_id = feed.comment_id
    process(nil, realtime_subscription) if @comment_id
  end
  
  def process(koala_comment = nil, real_time_update = true, convert = false)
    @koala_comment = koala_comment if koala_comment.present?
    return if feed_converted?(@koala_comment.feed_id)
    
    post = account.facebook_posts.find_by_post_id(@koala_comment.parent_post)
    if post.blank?
      #post flow will convert all comments and reply to comments 
      add_as_post_and_note(@feed, @koala_comment.parent_post, convert)
    else
      note = add_as_note(post.postable, @koala_comment, real_time_update)
      process_reply_to_comments
    end    
  end

  #reply to a ticket
  def send_reply(ticket, note)
    return_value = sandbox(true) {
      post_id =  ticket.fb_post.post_id
      comment = @rest.put_comment(post_id, note.body)
      comment.symbolize_keys!

      #create fb_post for this note
      unless comment.blank?
        note.create_fb_post({
          :post_id          => comment[:id],
          :facebook_page_id => ticket.fb_post.facebook_page_id,
          :account_id       => ticket.account_id,
          :parent_id        => ticket.fb_post.id,
          :post_attributes  => {
            :can_comment => false
          }
        })
      end
    }
    return_value
  end

  def in_reply_to
    @koala_comment.parent_post
  end

  def feed_hash
    @koala_comment.comment
  end
  
  def feed_id
    @koala_comment.comment_id
  end
  
  private 
    def add_as_post_and_note(feed, post_id, convert = false)
      convert_comment, convert_args = convert_args(koala_comment, convert)
      if convert_comment
        @koala_post.fetch(post_id)
        type = @koala_post.company_post? ? POST_TYPE[:status] : POST_TYPE[:post]
        ("facebook/core/"+"#{type}").camelize.constantize.new(@fan_page, @koala_post).process(@koala_post, realtime_subscription, true)
      end
    end
    
    def process_comment_as_ticket(convert_args)
      add_as_ticket(@fan_page, @koala_comment, realtime_subscription, convert_args)
    end
    
    def process_reply_to_comments
      @koala_comment.comments.each do |c|
        comment = koala_reply_to_comment(c)
        Facebook::Core::ReplyToComment.new(@fan_page, comment).process(nil, realtime_subscription)
      end
    end
    
    def koala_reply_to_comment(comment)
      koala_comment = Facebook::KoalaWrapper::Comment.new(@fan_page)
      koala_comment.comment = comment
      koala_comment.parse
      koala_comment
    end
    
    def realtime_subscription
      fan_page.realtime_subscription
    end 
    
end
