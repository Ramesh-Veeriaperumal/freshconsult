require 'lib/error_handle.rb' 
include ErrorHandle 

namespace :twitter do
  desc 'Check for New twitter feeds..'
  task :fetch => :environment do    
    puts "Twitter task initialized at #{Time.zone.now}"
    Account.active_accounts.each do |account|
      Account.reset_current_account
      twitter_handles = account.twitter_handles.find(:all, :conditions => ["capture_dm_as_ticket = 1 or capture_mention_as_ticket = 1"])    
      twitter_handles.each do |twt_handle| 
        sandbox do ### starts ####
          wrapper = TwitterWrapper.new twt_handle
          twitter = wrapper.get_twitter
          #From id to Id....
          if twt_handle.capture_dm_as_ticket
            tweets = nil
            if twt_handle.last_dm_id.blank?
              tweets = twitter.direct_messages
            else
              tweets = twitter.direct_messages({:since_id =>twt_handle.last_dm_id})
            end
        
            last_tweet_id = tweets[0].id unless tweets.blank?       
            create_ticket_from_dm (tweets , twt_handle )       
            twt_handle.update_attribute(:last_dm_id, last_tweet_id) unless last_tweet_id.blank?
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
            create_ticket_from_mention (tweets ,twt_handle )        
            twt_handle.update_attribute(:last_mention_id, last_tweet_id) unless last_tweet_id.blank?
         end       
       end ### ends ####
     end
   end
   puts "Twitter closed at #{Time.zone.now}"
 end
 
 def create_ticket_from_mention tweets , twt_handle
     tweets.each do |twt|
         @sender = twt.user 
         @account = twt_handle.account
         @user = get_user(@sender.screen_name)
         
         if twt.in_reply_to_status_id.blank?         
            add_tweet_as_ticket twt , twt_handle , :mention
         else
            tweet = @account.tweets.find_by_tweet_id(twt.in_reply_to_status_id)
            unless tweet.blank?
              ticket = tweet.get_ticket
              add_tweet_as_note twt , twt_handle , :mention , ticket
            else
              add_tweet_as_ticket twt , twt_handle , :mention
            end
         end
     end
 end

 def create_ticket_from_dm tweets , twt_handle
   tweets.each do |twt|
         @sender = twt.sender 
         @account = twt_handle.account
         @user = get_user(@sender.screen_name)
         previous_ticket = @user.tickets.visible.newest(1).first
         last_reply = (!previous_ticket.notes.blank? && !previous_ticket.notes.latest_twitter_comment.blank?) ? previous_ticket.notes.latest_twitter_comment.first : previous_ticket  unless previous_ticket.blank?
         
         if last_reply && (Time.zone.now < (last_reply.created_at + twt_handle.dm_thread_time.seconds))
           add_tweet_as_note twt , twt_handle , :dm , previous_ticket
         else
            add_tweet_as_ticket twt , twt_handle , :dm
         end
     end
 end
  
  def add_tweet_as_ticket twt , twt_handle , twt_type
     
     ticket = @account.tickets.build(
      :subject => twt.text,
      :description => twt.text,
      :twitter_id => @sender.screen_name,
      :email_config_id => twt_handle.product_id,
      :group_id => twt_handle.product.group_id,
      :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
      :tweet_attributes => {:tweet_id => twt.id, :account_id => @account.id , :tweet_type => twt_type.to_s} )
      
      if ticket.save
        puts "This ticket has been saved"
      else
        puts "error while saving the ticket:: #{ticket.errors.to_json}"
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
  
  def add_tweet_as_note twt,twt_handle, twt_type , ticket
    
      note = ticket.notes.build(
        :body => twt.text,
        :incoming => true,
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
        :account_id => twt_handle.account_id,
        :user_id => @user.id ,
        :tweet_attributes => {:tweet_id => twt.id, :account_id => @account.id , :tweet_type => twt_type.to_s}
       )
      if note.save
        puts "This note has been added"
      else
        puts "error while saving the ticket:: #{note.errors.to_json}"
      end
  end
  
end