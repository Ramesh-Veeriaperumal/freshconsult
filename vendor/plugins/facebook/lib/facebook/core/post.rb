class Facebook::Core::Post

  def initialize(fan_page)
    @account = fan_page.account
    @fan_page = fan_page
    @koala_post = Facebook::KoalaWrapper::Post.new(fan_page)
  end

  def add(feed)
    if feed.post_id
      post_id = feed.post_id
      #hack because facebook doesn't differenciate between status and post
      post_id = feed.page_id + "_" + post_id unless post_id.include?("_")
      return if @account.facebook_posts.find_by_post_id(post_id)
      @koala_post.fetch(post_id)
      add_as_ticket if @koala_post.create_ticket
    end
  end

  def add_as_ticket(koala_post=nil, real_time_update=true)
    @koala_post  = koala_post if koala_post
    group_id = @fan_page.product.primary_email_config.group_id unless @fan_page.product.blank?
    if !@koala_post.description.blank? || (@koala_post.feed_type == "photo" || @koala_post.feed_type == "video")
      @ticket = @account.tickets.build(
        :subject => @koala_post.subject,
        :requester => @koala_post.requester,
        :product_id => @fan_page.product_id,
        :group_id => group_id,
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:facebook],
        :created_at => @koala_post.created_at,
        :fb_post_attributes => {
          :post_id => @koala_post.post_id,
          :facebook_page_id => @fan_page.id,
          :account_id => @account.id
        },
        :ticket_body_attributes => {
          :description => @koala_post.description,
          :description_html => @koala_post.description_html
        }
      )

      if @ticket.save_ticket
        if real_time_update && !@koala_post.created_at.blank?
          @fan_page.update_attribute(:fetch_since, @koala_post.created_at.to_i)
        end

        #Along with the post, create notes for all the available comments
        if @koala_post.comments
          @koala_post.comments.each do |comment|
            Facebook::Core::Comment.new(@fan_page).add_as_note(@ticket,comment)
          end
        end
      else
        puts "error while saving the ticket:: #{@ticket.errors.to_json}"
      end
    end
  end
end
