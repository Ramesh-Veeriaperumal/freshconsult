#Remove this class after completly migrating to realtime facebook
class Social::FacebookPosts

  def initialize(fb_page  , options = {} )
    @account = options[:current_account]  || fb_page.account
    @rest = Koala::Facebook::GraphAndRestAPI.new(fb_page.access_token)
    @fb_page = fb_page
  end

  def fetch

    until_time = @fb_page.fetch_since

    if @fb_page.import_visitor_posts && @fb_page.import_company_posts
      query = "SELECT post_id, message, actor_id, updated_time, created_time FROM stream WHERE source_id=#{@fb_page.page_id} and
                (created_time > #{@fb_page.fetch_since} or updated_time > #{@fb_page.fetch_since})"
    elsif @fb_page.import_visitor_posts
      query = "SELECT post_id, message, actor_id, updated_time, created_time FROM stream WHERE source_id=#{@fb_page.page_id} and
              actor_id!=#{@fb_page.page_id} and (created_time > #{@fb_page.fetch_since} or updated_time > #{@fb_page.fetch_since})"
    elsif @fb_page.import_company_posts
      query = "SELECT post_id, message, actor_id, updated_time, created_time FROM stream WHERE source_id=#{@fb_page.page_id} and
              actor_id=#{@fb_page.page_id} and (created_time > #{@fb_page.fetch_since} or updated_time > #{@fb_page.fetch_since})"
    end
    if query
      feeds = @rest.fql_query(query)
      until_time = feeds.collect {|f| f["updated_time"]}.compact.max unless feeds.blank?
      create_ticket_from_feeds feeds
      get_comment_updates
      @fb_page.update_attribute(:fetch_since, until_time) unless until_time.blank?
    end
  end

  def create_ticket_from_feeds feeds
    feeds.each do |feed|
      feed.symbolize_keys!
      if feed[:created_time] >  @fb_page.fetch_since
        add_wall_post_as_ticket feed
      end
    end
  end

  def add_wall_post_as_ticket(feed)

    group_id = @fb_page.product.primary_email_config.group_id unless @fb_page.product.blank?
    Rails.logger.debug "add_wall_post_as_ticket ::post_id::  #{feed[:post_id]} :time: #{feed[:created_time]}"
    profile_id = feed[:actor_id]
    requester = get_facebook_user(profile_id)
    unless feed[:message].blank?
      @ticket = @account.tickets.build(
        :subject => truncate_subject(feed[:message], 100),
        :requester => requester,
        :product_id => @fb_page.product_id,
        :group_id => group_id,
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:facebook],
        :created_at => Time.zone.at(feed[:created_time]),
        :fb_post_attributes => {:post_id => feed[:post_id], :facebook_page_id => @fb_page.id ,:account_id => @account.id},
        :ticket_body_attributes => {:description => feed[:message],
                                    :description_html =>get_html_content(feed[:post_id]) })
      
      if @ticket.save_ticket
        Rails.logger.debug "This ticket has been saved"
      else
        Rails.logger.debug "error while saving the ticket:: #{@ticket.errors.to_json}"
      end
    end
  end

  def get_html_content post_id
    Rails.logger.debug "get_html_content"
    post = @rest.get_object(post_id)
    post.symbolize_keys!
    html_content =  CGI.escapeHTML(post[:message]).to_s
    if "video".eql?(post[:type])

      desc = post[:description] || ""
      html_content =  "<div class=\"facebook_post\"><a class=\"thumbnail\" href=\"#{post[:link]}\" target=\"_blank\"><img src=\"#{post[:picture]}\"></a>" +
        "<div><p><a href=\"#{post[:link]}\" target=\"_blank\">"+post[:name].to_s+"</a></p>"+
        "<p><strong>"+html_content+"</strong></p>"+
        "<p>"+desc+"</p>"+
        "</div></div>"

    elsif "photo".eql?(post[:type])

      html_content =  "<div class=\"facebook_post\"><p>"+html_content+"</p>"+
        "<p><a href=\"#{post[:link]}\" target=\"_blank\"><img src=\"#{post[:picture]}\"></a></p></div>"

    end

    return html_content

  end

  def get_facebook_user(profile_id)
    user = @account.all_users.find_by_fb_profile_id(profile_id)
    unless user
      profile =  @rest.get_object(profile_id)
      profile.symbolize_keys!
      user = @account.contacts.new
      if user.signup!({:user => {:fb_profile_id => profile_id, :name => profile[:name] || profile[:id],
                                 :active => true,
                                 :helpdesk_agent => false}})
      else
        Rails.logger.debug "unable to save the contact:: #{user.errors.inspect}"
      end
    end
    user
  end

  def add_comment_as_note feed

    post_id = feed[:post_id]
    post = @account.facebook_posts.find_by_post_id(post_id)

    comments = @rest.get_connections(post_id, "comments")
    comments = comments.reject(&:blank?)

    unless post.blank?
      @ticket = post.postable
    else
      add_wall_post_as_ticket (feed)
    end

    unless @ticket.blank?
      comments.each do |comment|
        comment.symbolize_keys!
        profile_id = comment[:from]["id"]
        user = get_facebook_user(profile_id)

        @note = @ticket.notes.build(
          :note_body_attributes => { :body => comment[:message]} ,
          :private => true ,
          :incoming => true,
          :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["facebook"],
          :account_id => @fb_page.account_id,
          :user => user,
          :created_at => Time.zone.parse(comment[:created_time]),
          :fb_post_attributes => {:post_id => comment[:id], :facebook_page_id =>@fb_page.id ,:account_id => @account.id}
        )

        begin
          user.make_current
          if @note.save_note

          else
            Rails.logger.debug "error while saving the note #{@note.errors.to_json}"
          end
        ensure
          User.reset_current_user
        end
      end
    end
  end

  def truncate_subject(subject , count)
    Rails.logger.debug "truncate subject #{subject}"
    (subject.length > count) ? "#{subject[0..(count - 1)]}..." : subject
  end

  def get_comment_updates
    query = "SELECT id, post_fbid, post_id, text, time, fromid FROM comment where post_id in
              (SELECT post_id FROM stream WHERE source_id = #{@fb_page.page_id} and (created_time > #{@fb_page.fetch_since} or updated_time > #{@fb_page.fetch_since})) and time > #{@fb_page.fetch_since}"
    
    comments =  @rest.fql_query(query)
    comments.each do |comment|
      comment.symbolize_keys!
      post_id = comment[:post_id]
      post = @account.facebook_posts.find_by_post_id(post_id)
      @ticket = post.postable unless post.nil?
      unless @ticket.nil?
        profile_id = comment[:fromid]
        user = get_facebook_user(profile_id)
        @note = @ticket.notes.build(
          :note_body_attributes => {:body => comment[:text]},
          :private => true,
          :incoming => true,
          :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["facebook"],
          :account_id => @fb_page.account_id,
          :user => user,
          :created_at => Time.zone.at(comment[:time]),
          :fb_post_attributes => {:post_id => comment[:id], :facebook_page_id =>@fb_page.id,
                                  :account_id => @account.id}
        )
        begin
          user.make_current
          unless @note.save_note
            Rails.logger.debug "error while saving the note :: #{@note.errors.to_json}"
          end
        rescue
          User.reset_current_user
        end
      end
    end
  end

end
