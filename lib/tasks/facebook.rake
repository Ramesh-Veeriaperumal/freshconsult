namespace :facebook do
  desc 'Check for New facebook feeds..'
  task :fetch => :environment do    
    puts "facebook..fetch is called"
    Account.active_accounts.each do |account|
      facebook_pages = account.facebook_pages.find(:all, :conditions => ["enable_page = 1"])    
      facebook_pages.each do |fan_page| 
        puts "facebook---fetch has been called for page :: #{fan_page.page_name}"
        #sandbox do ### starts ####
          # @fb_client = FBClient.new fan_page
          #fb_page = @fb_client.get_page
     
          
          @rest = Koala::Facebook::GraphAndRestAPI.new(fan_page.access_token)
             
      
          until_time = Time.zone.now
          
          query = "SELECT post_id,message,actor_id,updated_time,created_time,comments FROM stream WHERE source_id=#{fan_page.page_id} and actor_id!=#{fan_page.page_id} and updated_time > #{fan_page.fetch_since}"
          
          if fan_page.import_visitor_posts && fan_page.import_company_posts
           query = "SELECT post_id,message,actor_id ,updated_time,created_time,comments FROM stream WHERE source_id=#{fan_page.page_id} and updated_time > #{fan_page.fetch_since} "
          end
          
          feeds = @rest.fql_query(query)
          
           ### We need to handle time - zone problem , and first-updated time versus highest of the updated-time...
          until_time = feeds.collect {|f| f["updated_time"]}.compact.max unless feeds.blank?  
          
          create_ticket_from_feeds feeds ,fan_page      
          
          fan_page.update_attribute(:fetch_since, until_time) unless until_time.blank?
        
      # end ### ends ####
      end
    end
  end
  
  ##Need to consider the 
  def create_ticket_from_feeds feeds , fan_page
    
      feeds.each do |feed|
         
         feed.symbolize_keys!
         @account = fan_page.account
         puts "create_ticket_from_feeds: created_time  is #{feed[:created_time]}"
         #post_created_time = feed["created_time"]
         
         if feed[:created_time] >  fan_page.fetch_since  
            puts "create_ticket_from_feeds :: gonna cal add_wall_post"
            add_wall_post_as_ticket feed , fan_page 
         else
            add_comment_as_note feed , fan_page
         end
     end
  end
  
  def add_wall_post_as_ticket (feed , fan_page )
    
     group_id = fan_page.product.group_id unless fan_page.product.blank?
     puts "add_wall_post_as_ticket ::post_id::  #{feed[:post_id]}"
     profile_id = feed[:actor_id]
     requester = get_facebook_user(profile_id)
     @ticket = @account.tickets.build(
      :subject => feed[:message],
      :description => feed[:message],
      :requester => requester,
      :email_config_id => fan_page.product_id,
      :group_id => group_id,
      :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:facebook],
      :fb_post_attributes => {:post_id => feed[:post_id], :facebook_page_id =>fan_page.id ,:account_id => @account.id} )
      
      if @ticket.save
        if feed[:comments]["count"] > 0
           puts"ticket is saved and it has more comments :: #{feed[:comments]["count"]}"
           add_comment_as_note feed , fan_page
        end
        puts "This ticket has been saved"
      else
        puts "error while saving the ticket:: #{@ticket.errors.to_json}"
      end
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
  
  def add_comment_as_note feed,fan_page 
    puts "add_comment_as_note :: post_id :#{feed[:post_id]}"
    ## we need to 
    post_id = feed[:post_id]
    post = @account.facebook_posts.find_by_post_id(post_id)
    comment_count =feed[:comments]["count"]
    
    comments = nil
    if comment_count >2
      comments = @rest.get_connections(post_id, "comments" , {:since =>fan_page.fetch_since})
     
    else
      comments = feed[:comments]["comment_list"].collect {|c| c  if c["time"].to_i > fan_page.fetch_since}
    end
    #puts "The post comment count is ....#{comment_count}"
    #comments = feed[:comments]["comment_list"].collect {|c| c  if c["time"].to_i > fan_page.fetch_since}
    comments = comments.reject(&:blank?)
    
    puts "comments to add ..size :: #{comments.size}"
    
    unless post.blank?  
      @ticket = post.postable 
    else
      add_wall_post_as_ticket (feed,fan_page)
    end
   
    unless @ticket.blank?    
      comments.each do |comment|
        comment.symbolize_keys!
        
        profile_id = comment[:fromid] || comment[:from]["id"]
        user = get_facebook_user(profile_id)
        
        @note = @ticket.notes.build(
                        :body => comment[:text] || comment[:message],
                        :private => true ,
                        :incoming => true,
                        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["facebook"],
                        :account_id => fan_page.account_id,
                        :user => user,
                        :fb_post_attributes => {:post_id => comment[:id], :facebook_page_id =>fan_page.id ,:account_id => @account.id}
                                  )
      if @note.save
        puts "This note has been added"
      else
        puts "error while saving the note #{@note.errors.to_json}"
      end
      
    end
    
   end
 end
  
  def sandbox
      begin
        yield
      rescue Errno::ECONNRESET => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Timeout::Error => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue EOFError => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Errno::ETIMEDOUT => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue OpenSSL::SSL::SSLError => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue SystemStackError => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Exception => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue 
        puts e.to_s
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
      end
    end
  
end