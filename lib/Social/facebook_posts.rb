class Social::FacebookPosts
  
 def initialize(fb_page  , options = {} )
    @account = options[:current_account]  || fb_page.account
    @rest = Koala::Facebook::GraphAndRestAPI.new(fb_page.access_token)
    @fb_page = fb_page
 end
 
 def fetch
  
   until_time = Time.zone.now   
   query = "SELECT post_id,message,actor_id,updated_time,created_time,comments FROM stream WHERE source_id=#{@fb_page.page_id} and actor_id!=#{@fb_page.page_id} and updated_time > #{@fb_page.fetch_since}"
   
   if @fb_page.import_visitor_posts && @fb_page.import_company_posts
    query = "SELECT post_id,message,actor_id ,updated_time,created_time,comments FROM stream WHERE source_id=#{@fb_page.page_id} and updated_time > #{@fb_page.fetch_since} "
   end
          
   feeds = @rest.fql_query(query)
   until_time = feeds.collect {|f| f["updated_time"]}.compact.max unless feeds.blank?        
   create_ticket_from_feeds feeds               
   @fb_page.update_attribute(:fetch_since, until_time) unless until_time.blank?
 end
 
  def create_ticket_from_feeds feeds
      feeds.each do |feed|
        feed.symbolize_keys!
         if feed[:created_time] >  @fb_page.fetch_since  
            add_wall_post_as_ticket feed 
         else
            add_comment_as_note feed
         end
     end
  end
  
  def add_wall_post_as_ticket (feed)
    
     group_id = @fb_page.product.group_id unless @fb_page.product.blank?
     puts "add_wall_post_as_ticket ::post_id::  #{feed[:post_id]} :time: #{feed[:created_time]}"
     profile_id = feed[:actor_id]
     requester = get_facebook_user(profile_id)
     unless feed[:message].blank?
        @ticket = @account.tickets.build(
          :subject => truncate_subject(feed[:message], 100),
          :description => feed[:message],
          :description_html => get_html_content(feed[:post_id]),
          :requester => requester,
          :email_config_id => @fb_page.product_id,
          :group_id => group_id,
          :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:facebook],
          :created_at => Time.at(feed[:created_time]).to_s(:db),
          :fb_post_attributes => {:post_id => feed[:post_id], :facebook_page_id =>@fb_page.id ,:account_id => @account.id} )
      
       if @ticket.save
        if feed[:comments]["count"] > 0
           puts"ticket is saved and it has more comments :: #{feed[:comments]["count"]}"
           add_comment_as_note feed
        end
        puts "This ticket has been saved"
       else
        puts "error while saving the ticket:: #{@ticket.errors.to_json}"
       end
     end
  end
  
  def get_html_content post_id
    puts "get_html_content"
    post = @rest.get_object(post_id)
    post.symbolize_keys!
    html_content =  post[:message]
    if "video".eql?(post[:type]) 
            
     desc = post[:description] || ""
     html_content =  "<div class=\"facebook_post\"><a class=\"thumbnail\" href=\"#{post[:link]}\" target=\"_blank\"><img src=\"#{post[:picture]}\"></a>" +
                     "<div><p><a href=\"#{post[:link]}\" target=\"_blank\">"+post[:name]+"</a></p>"+
                     "<p><strong>"+post[:caption]+"</strong></p>"+
                     "<p>"+desc+"</p>"+
                     "</div></div>"
      
    elsif "photo".eql?(post[:type])
      
      html_content =  "<div class=\"facebook_post\"><p>"+post[:message]+"</p>"+
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
      if user.signup!({:user => {:fb_profile_id => profile_id, :name => profile[:name], 
                    :active => true,
                    :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}})
       else
          puts "unable to save the contact:: #{user.errors.inspect}"
       end   
    end
     user
  end
  
  def add_comment_as_note feed
  
    post_id = feed[:post_id]
    post = @account.facebook_posts.find_by_post_id(post_id)
   
    comments = @rest.get_connections(post_id, "comments" , {:since =>@fb_page.fetch_since})  
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
        created_at  =  Time.parse(comment[:created_time])
        
        @note = @ticket.notes.build(
                        :body => comment[:message],
                        :private => true ,
                        :incoming => true,
                        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["facebook"],
                        :account_id => @fb_page.account_id,
                        :user => user,
                        :created_at => created_at.to_s(:db),
                        :fb_post_attributes => {:post_id => comment[:id], :facebook_page_id =>@fb_page.id ,:account_id => @account.id}
                                  )
      if @note.save
        
      else
        puts "error while saving the note #{@note.errors.to_json}"
      end
      
    end
    
   end
 end 

  def truncate_subject(subject , count)
    puts "truncate subject #{subject}"
    (subject.length > count) ? "#{subject[0..(count - 1)]}..." : subject
  end
    
end