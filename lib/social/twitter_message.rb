class Social::TwitterMessage

attr_accessor :twitter , :twt_handle 
include Social::TwitterUtil

 def initialize(twt_handle  , options = {} )
    @account = options[:current_account]  || twt_handle.account
    wrapper = TwitterWrapper.new twt_handle
    self.twitter = wrapper.get_twitter
    self.twt_handle = twt_handle
 end
 
 def process
   tweets = twt_handle.last_dm_id.blank? ? twitter.direct_messages : twitter.direct_messages({:since_id =>twt_handle.last_dm_id})
   last_tweet_id = tweets[0].id unless tweets.blank?       
   create_ticket_from_dm (tweets , twt_handle )       
   twt_handle.update_attribute(:last_dm_id, last_tweet_id) unless last_tweet_id.blank?
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

 end