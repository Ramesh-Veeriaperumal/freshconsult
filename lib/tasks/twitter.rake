#require 'lib/helpdesk_controller_methods'
#include HelpdeskControllerMethods
namespace :twitter do
  desc 'Check for New twitter feeds..'
  task :fetch => :environment do    
    twitter_handles = Admin::TwitterHandles.find(:all, :conditions =>{:capture_dm_as_ticket =>true , :capture_mention_as_ticket =>true})    
    twitter_handles.each do |twt_handle| 
      
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
        twt_handle.update_attribute(:last_mention_id, last_tweet_id)
      end       
      
    end
    
  end
  ##Need to consider the 
  def create_ticket_from_tweet tweets , twt_handle
      
      tweets.each do |twt|
        
         RAILS_DEFAULT_LOGGER.debug "twitter dms: rach  :: #{twt.inspect}"              
         if twt.in_reply_to_status_id.blank?         
             add_tweet_as_ticket twt , twt_handle
         else
             add_tweet_as_note twt , twt_handle
         end
         
         ## img_url = twt.sender.profile_image_url ## This is for avatar
         ## in_reply_to = twt.in_reply_to_status_id #This is for threading
         ##         
         #@ticket.user = User.first #Need to change this as system user....         
    end
  end
  
  def add_tweet_as_ticket twt , twt_handle
     sender = twt.sender || twt.user
     @ticket = twt_handle.account.tickets.new
     @ticket.subject = twt.text
     @ticket.description = twt.text
     @ticket.twitter_id = sender.screen_name
     @ticket.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter]
     @ticket.tweet_id = twt.id
     RAILS_DEFAULT_LOGGER.debug "ticket object before saving  :: #{@ticket.inspect} and screen name is :#{sender.screen_name}" 
     if @ticket.save
        RAILS_DEFAULT_LOGGER.debug "This ticket has been saved"
            #move_attachments   
     else
           RAILS_DEFAULT_LOGGER.debug "error while saving the ticket:: #{@ticket.errors.inspect}"
     end
  end
  
  def add_tweet_as_note twt,twt_handle    
    @ticket = twt_handle.account.tickets.find_by_tweet_id(twt.in_reply_to_status_id)     
    if @ticket.blank?
       @note = twt_handle.account.notes.find_by_tweet_id(twt.in_reply_to_status_id)
       @ticket = @note.notable unless @note.blank?
    end
   
    
    unless @ticket.blank?
           if  @ticket.notes.create(
                  :body => twt.text,
                  :private => true ,
                  :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['twitter'],
                  :account_id => twt_handle.account_id,
                  :user_id => User.first && User.first.id  
                  ) 
                  
           else
             RAILS_DEFAULT_LOGGER.debug "error while saving the note #{@ticket.notes.errors.inspect}"
           end
      
    else
      add_tweet_as_ticket (twt,twt_handle)
    end
    #need to change user_id as system user/twitter account user
  end
  
end