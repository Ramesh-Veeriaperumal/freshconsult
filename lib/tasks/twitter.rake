namespace :twitter do
  desc 'Check for New twitter feeds..'
  task :fetch => :environment do    
    Account.active_accounts.each do |account|
      twitter_handles = account.twitter_handles.find(:all, :conditions => ["capture_dm_as_ticket = 1 or capture_mention_as_ticket = 1"])    
      twitter_handles.each do |twt_handle| 
        sandbox do ### starts ####
          @wrapper = TwitterWrapper.new twt_handle
          twitter = @wrapper.get_twitter
          #From id to Id....
          if twt_handle.capture_dm_as_ticket
            tweets = nil
            if twt_handle.last_dm_id.blank?
              tweets = twitter.direct_messages
            else
              tweets = twitter.direct_messages({:since_id =>twt_handle.last_dm_id})
            end
        
            last_tweet_id = tweets[0].id unless tweets.blank?       
            create_ticket_from_tweet tweets , twt_handle        
            twt_handle.update_attribute(:last_dm_id, last_tweet_id)
          end
        
          #From id to Id....
          if twt_handle.capture_mention_as_ticket
            tweets = nil
            if twt_handle.last_mention_id.blank?
              tweets = twitter.mentions
            else
              tweets = twitter.mentions({:since_id =>twt_handle.last_mention_id})
            end       
            last_tweet_id = tweets[0].id unless tweets.blank?   
            create_ticket_from_tweet tweets ,twt_handle        
            twt_handle.update_attribute(:last_mention_id, last_tweet_id) unless last_tweet_id.blank?
         end       
       end ### ends ####
      end
    end
  end
  
  ##Need to consider the 
  def create_ticket_from_tweet tweets , twt_handle
      tweets.each do |twt|
         @sender = twt.sender || twt.user 
         @account = twt_handle.account
         @user = get_user(@sender.screen_name)
         
          if twt.in_reply_to_status_id.blank?         
            add_tweet_as_ticket twt , twt_handle
          else
            add_tweet_as_note twt , twt_handle
          end
     end
  end
  
  def add_tweet_as_ticket twt , twt_handle
     
     @ticket = @account.tickets.build(
      :subject => twt.text,
      :description => twt.text,
      :twitter_id => @sender.screen_name,
      :email_config_id => twt_handle.product_id,
      :group_id => twt_handle.product.group_id,
      :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
      :tweet_attributes => {:tweet_id => twt.id, :account_id => @account.id} )
      
      if @ticket.save
        puts "This ticket has been saved"
      else
        puts "error while saving the ticket:: #{@ticket.errors.to_json}"
      end
  end
  
  def get_user(screen_name)
    user = @account.all_users.find_by_twitter_id(screen_name)
    unless user
      user = @account.contacts.new
      user.signup!({:user => {:twitter_id => screen_name, :name => screen_name, 
                    :active => true,
                    :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}})
      end
     user
  end
  
  def add_tweet_as_note twt,twt_handle 
    
    tweet = @account.tweets.find_by_tweet_id(twt.in_reply_to_status_id)
    
    unless tweet.nil?  
      @ticket = tweet.tweetable.notable if  tweet.tweetable_type.eql?('Helpdesk::Note')
      @ticket = tweet.tweetable if  tweet.tweetable_type.eql?('Helpdesk::Ticket')
    end
    
    unless @ticket.blank?
      @note = @ticket.notes.create(
        :body => twt.text,
        :private => true ,
        :incoming => true,
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
        :account_id => twt_handle.account_id,
        :user_id => @user.id ,
        :tweet_attributes => {:tweet_id => twt.id, :account_id => @account.id}
       )
    else
      add_tweet_as_ticket (twt,twt_handle)
    end
  end
  
  def sandbox
      begin
        yield
      rescue Errno::ECONNRESET => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Timeout::Error => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue EOFError => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Errno::ETIMEDOUT => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue OpenSSL::SSL::SSLError => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue SystemStackError => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Exception => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue 
        puts e.to_s
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
      end
    end
  
end