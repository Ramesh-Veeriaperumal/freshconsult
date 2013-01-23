module Conversations::Twitter
  def send_tweet_as_mention
    reply_twitter = current_account.twitter_handles.find(params[:twitter_handle])
    unless reply_twitter.nil?
      begin
        @wrapper = TwitterWrapper.new reply_twitter
        twitter = @wrapper.get_twitter
        latest_comment = @parent.notes.latest_twitter_comment.first
        status_id = latest_comment.nil? ? @parent.tweet.tweet_id : latest_comment.tweet.tweet_id
        twitter.update(validate_tweet(@item.body), {:in_reply_to_status_id => status_id})
      rescue
        flash.now[:notice] = t('twitter.not_authorized')
      end
    end
  end

  def send_tweet_as_dm
    logger.debug "Called  send_tweet_as_dm send_tweet_as_dm "
    reply_twitter = current_account.twitter_handles.find(params[:twitter_handle])
    unless reply_twitter.nil?
      begin
        @wrapper = TwitterWrapper.new reply_twitter
        twitter = @wrapper.get_twitter
        latest_comment = @parent.notes.latest_twitter_comment.first
        status_id = latest_comment.nil? ? @parent.tweet.tweet_id : latest_comment.tweet.tweet_id    
        req_twt_id = latest_comment.nil? ? @parent.requester.twitter_id : latest_comment.user.twitter_id
        resp = twitter.direct_message_create(req_twt_id, @item.body)
     rescue  
        flash.now[:notice] = t('twitter.not_authorized')
     end
    end
  end

  def validate_tweet tweet
    twitter_id = "@#{@parent.requester.twitter_id}" 
    return tweet if ( tweet[0,twitter_id.length] == twitter_id)
    twt_text = (twitter_id+" "+  tweet)
    twt_text = twt_text[0,Social::Tweet::LENGTH - 1] if twt_text.length > Social::Tweet::LENGTH
    return twt_text
  end
end