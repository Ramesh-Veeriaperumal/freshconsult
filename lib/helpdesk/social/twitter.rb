module Helpdesk::Social::Twitter  

  def send_tweet_as_mention(ticket = @parent, note = @item)
    return_value = twt_sandbox(0) {
      @reply_twitter = current_account.twitter_handles.find(reply_twitter_handle(ticket))
      unless @reply_twitter.nil?
        twitter =  TwitterWrapper.new(@reply_twitter).get_twitter
        latest_comment = ticket.notes.latest_twitter_comment.first
        status_id = latest_comment.nil? ? ticket.tweet.tweet_id : latest_comment.tweet.tweet_id
        twt = twitter.update(validate_tweet(note.body, ticket), {:in_reply_to_status_id => status_id})
        process_tweet note, twt, reply_twitter_handle(ticket)
      end
    }
    return_value
  end

  def send_tweet_as_dm(ticket = @parent, note = @item)
    return_value = twt_sandbox(0) {
      @reply_twitter = current_account.twitter_handles.find(reply_twitter_handle(ticket))
      unless @reply_twitter.nil?
        twitter =  TwitterWrapper.new(@reply_twitter).get_twitter
        latest_comment = ticket.notes.latest_twitter_comment.first
        status_id = latest_comment.nil? ? ticket.tweet.tweet_id : latest_comment.tweet.tweet_id    
        req_twt_id = latest_comment.nil? ? ticket.requester.twitter_id : latest_comment.user.twitter_id
        resp = twitter.direct_message_create(req_twt_id, note.body)
        process_tweet note, twt, reply_twitter_handle(ticket)
      end
    }
    return_value
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

    def process_tweet note, twt, handle
      note.create_tweet({:tweet_id => twt.id, :twitter_handle_id => handle })
    end

    def twt_sandbox(return_value = nil)
      begin
        return_value = yield
      rescue Timeout::Error
        puts "TIMEOUT - rescued - wait for 5 seconds and then proceed." 
        sleep(5) 
      rescue Twitter::Error::Unauthorized => e
        @reply_twitter.state = Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]
        @reply_twitter.last_error = e.to_s
        @reply_twitter.save
        NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => @reply_twitter.account_id,
                  :id => @reply_twitter.id}})
        puts "Twitter Api Error -#{e.to_s} :: Account_id => #{@reply_twitter.account_id}
                                  :: id => #{@reply_twitter.id} "
        return_value = false
      rescue Exception => e
        puts "Something wrong happened in twitter! #{e.to_s} :: Account_id => #{@reply_twitter.account_id}
                                  :: id => #{@reply_twitter.id}"
        NewRelic::Agent.notice_error(e, {:custom_params => {:account_id => @reply_twitter.account_id,
                  :id => @reply_twitter.id}})
      end  
      return return_value   
  end
end
