class Facebook::Core::Comment
  include Facebook::Core::Util
  include Facebook::KoalaWrapper::ExceptionHandler

  def initialize(fan_page)
    @account = fan_page.account
    @fan_page = fan_page
    @rest = Koala::Facebook::GraphAndRestAPI.new(fan_page.page_token)
    @koala_post = Facebook::KoalaWrapper::Post.new(fan_page)
    @koala_comment = Facebook::KoalaWrapper::Comment.new(fan_page)
  end

  def add(feed)
    @comment_id = feed.comment_id
    if @comment_id
      post_id = feed.page_id + "_" + feed.parent_id
      post = @account.facebook_posts.find_by_post_id(post_id)
      return add_as_post_and_note(post_id,feed) if post.blank?
      add_as_note(post.postable)
    end
  end

  #make comment_id as instance varaiable merge create_note and add as note
  def add_as_note(ticket, comment=nil, real_time_update=true)
    @comment_id = comment["id"] if comment
    return if @account.facebook_posts.find_by_post_id(@comment_id)
    if comment
      @koala_comment.comment = comment
      @koala_comment.parse
    else
      @koala_comment.fetch(@comment_id)
    end
    unless ticket.blank? || @koala_comment.comment.blank?
      @note = ticket.notes.build(
        :note_body_attributes => {
          :body => @koala_comment.message
        },
        :private => true ,
        :incoming => true,
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["facebook"],
        :account_id => @fan_page.account_id,
        :user => @koala_comment.user,
        :created_at => @koala_comment.created_at,
        :fb_post_attributes => {
          :post_id => @koala_comment.comment_id,
          :facebook_page_id =>@fan_page.id ,
          :account_id => @account.id
        }
      )
      begin
        @koala_comment.user.make_current
        if @note.save_note
          if real_time_update && !@koala_comment.created_at.blank?
            @fan_page.update_attribute(:fetch_since, @koala_comment.created_at.to_i)
          end
        else
          puts "error while saving the note #{@note.errors.to_json}"
        end
      ensure
        User.reset_current_user
      end
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
          :post_id => comment[:id],
          :facebook_page_id => ticket.fb_post.facebook_page_id,
          :account_id => ticket.account_id
        })
      end
    }
    return_value
  end

  private

    def add_as_post_and_note(post_id,feed)
      # one more hack nothing can be done facebook bug
      begin
        @koala_post.fetch(post_id)
      rescue Exception => e
        @koala_post.fetch(feed.parent_id,feed.page_id)
      end
      if @koala_post.create_ticket
        Facebook::Core::Post.new(@fan_page).add_as_ticket(@koala_post)
        post = @account.facebook_posts.find_by_post_id(post_id)
        return if post.blank?
        add_as_note(post.postable)
      end
    end

end
