namespace :twitter do
  desc 'Check for New twitter feeds..'
  task :fetch => :environment do    
    twitter_handles = Social::TwitterHandle.find(:all, :conditions =>{:capture_dm_as_ticket =>true , :capture_mention_as_ticket =>true})    
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
  ##Need to consider the 
  def create_ticket_from_tweet tweets , twt_handle
      tweets.each do |twt|
         @sender = twt.sender || twt.user 
         @user = get_user(twt_handle.product.account, @sender.screen_name)
         
         if @user.blank?         
          add_tweet_as_ticket twt , twt_handle
         else
          add_tweet_as_note twt , twt_handle 
         end
     end
  end
  
  def add_tweet_as_ticket twt , twt_handle
     
     @ticket = twt_handle.product.account.tickets.build(
      :subject => twt.text,
      :description => twt.text,
      :twitter_id => @sender.screen_name,
      :email_config_id => twt_handle.product_id,
      :group_id => twt_handle.product.group_id,
      :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
      :tweet_attributes => {:tweet_id => twt.id} )
      
      if @ticket.save
        puts "This ticket has been saved"
      else
        puts "error while saving the ticket:: #{@ticket.errors.to_json}"
      end
  end
  
  def get_user(account, screen_name)
    user = account.all_users.find_by_twitter_id(screen_name)
    unless user
      user = account.contacts.new
      user.signup!({:user => {:twitter_id => screen_name, :name => screen_name, 
         :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}})
      end
     user
  end
  
  def get_open_tkt
    @user.open_tickets.first
  end
  
  def add_tweet_as_note twt,twt_handle 

    @ticket = get_open_tkt
    unless @ticket.blank?
      @note = @ticket.notes.create(
        :body => twt.text,
        :private => true ,
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
        :account_id => twt_handle.product.account_id,
        :user_id => @user.id ,
        :tweet_attributes => {:tweet_id => twt.id}
       )
    else
      add_tweet_as_ticket (twt,twt_handle)
    end
  end
  
  def sandbox
      begin
        yield
      rescue Errno::ECONNRESET => e
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Timeout::Error => e
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue EOFError => e
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Errno::ETIMEDOUT => e
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue OpenSSL::SSL::SSLError => e
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue SystemStackError => e
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue 
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
      end
    end
  
end