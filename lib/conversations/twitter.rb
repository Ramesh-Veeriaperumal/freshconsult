module Conversations::Twitter

  include Social::Twitter::DynamoUtil

  def send_tweet_as_mention(ticket = @parent, note = @item)
    return_value = twt_sandbox(0) {
      current_account = ticket.account if current_account.nil?
      reply_handle_id = reply_twitter_handle(ticket)
      @reply_twitter = current_account.twitter_handles.find(reply_handle_id)

      unless @reply_twitter.nil?
        twitter =  TwitterWrapper.new(@reply_twitter).get_twitter
        latest_comment = ticket.notes.latest_twitter_comment.first
        latest_tweet = latest_comment.nil? ? ticket.tweet : latest_comment.tweet
        status_id = latest_tweet.tweet_id
        twt = twitter.update(validate_tweet(note.body.strip, ticket), {:in_reply_to_status_id => status_id})

        #Only social_streams will have a stream_id in the tweets table.
        unless latest_tweet.stream_id.nil?
          stream_id = "#{current_account.id}_#{latest_tweet.stream_id}"

          params = {
            :id => twt.attrs[:id_str],
            :in_reply_to_user_id => twt.attrs[:in_reply_to_user_id_str],
            :body => twt.attrs[:text],
            :in_reply_to_id => "#{status_id}",
            :posted_at => twt.attrs[:created_at]
          }

          #update dynamoDB tables with this reply
          update_reply(stream_id, params)
        end
        process_tweet note, twt, reply_handle_id, :mention
      end
    }
    return_value
  end

  def send_tweet_as_dm(ticket = @parent, note = @item)
    return_value = twt_sandbox(0) {
      current_account = ticket.account if current_account.nil?
      reply_handle_id = reply_twitter_handle(ticket)
      @reply_twitter = current_account.twitter_handles.find(reply_handle_id)
      unless @reply_twitter.nil?
        twitter =  TwitterWrapper.new(@reply_twitter).get_twitter
        latest_comment = ticket.notes.latest_twitter_comment.first
        latest_tweet = latest_comment.nil? ? ticket.tweet : latest_comment.tweet
        status_id = latest_tweet.tweet_id
        req_twt_id = latest_comment.nil? ? ticket.requester.twitter_id : latest_comment.user.twitter_id
        resp = twitter.direct_message_create(req_twt_id, note.body.strip)
        
        unless latest_tweet.stream_id.nil?
          stream_id = "#{current_account.id}_#{latest_tweet.stream_id}"

          params = {
            :id => resp.attrs[:id_str],
            :user_id => resp.attrs[:recipient_id_str],
            :body => resp.attrs[:text],
            :posted_at => resp.attrs[:created_at]
          }

          #update dynamoDB tables with this reply
          update_dm(stream_id, params)
        end
        process_tweet note, resp, reply_handle_id, :dm
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

    def process_tweet note, twt, handle_id, twt_type
      stream_id = @reply_twitter.default_stream_id
      note.create_tweet({
        :tweet_id => twt.id, 
        :tweet_type => twt_type.to_s, 
        :twitter_handle_id => handle_id,
        :stream_id => stream_id
       })
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
