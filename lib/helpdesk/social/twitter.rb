module Helpdesk::Social::Twitter  

  def send_tweet_as_mention(ticket = @parent, note = @item)
    reply_twitter = current_account.twitter_handles.find(reply_twitter_handle(ticket))
    unless reply_twitter.nil?
      begin
        twitter =  TwitterWrapper.new(reply_twitter).get_twitter
        latest_comment = ticket.notes.latest_twitter_comment.first
        status_id = latest_comment.nil? ? ticket.tweet.tweet_id : latest_comment.tweet.tweet_id
        twt = twitter.update(validate_tweet(note.body, ticket), {:in_reply_to_status_id => status_id})
        process_tweet note, twt
      rescue
        return false
      end
    end
    return true
  end

  def send_tweet_as_dm(ticket = @parent, note = @item)
    reply_twitter = current_account.twitter_handles.find(reply_twitter_handle(ticket))
    unless reply_twitter.nil?
      begin
        twitter =  TwitterWrapper.new(reply_twitter).get_twitter
        latest_comment = ticket.notes.latest_twitter_comment.first
        status_id = latest_comment.nil? ? ticket.tweet.tweet_id : latest_comment.tweet.tweet_id    
        req_twt_id = latest_comment.nil? ? ticket.requester.twitter_id : latest_comment.user.twitter_id
        resp = twitter.direct_message_create(req_twt_id, note.body)
        process_tweet note, twt
      rescue  
        return false
      end
    end
    return true
  end

  protected

    def validate_tweet tweet, ticket
      twitter_id = "@#{ticket.requester.twitter_id}" 
      return tweet if ( tweet[0,twitter_id.length] == twitter_id)
      twt_text = (twitter_id+" "+  tweet)
      twt_text = twt_text[0,Social::Tweet::LENGTH - 1] if twt_text.length > Social::Tweet::LENGTH
      return twt_text
    end

    def reply_twitter_handle ticket
      params[:twitter_handle].present? ? params[:twitter_handle] : ticket.fetch_twitter_handle 
      #params.key?(:twitter_handle)
    end

    def process_tweet note, twt
      note.create_tweet({:tweet_id => twt.id, :account_id => current_account.id})
    end
end
