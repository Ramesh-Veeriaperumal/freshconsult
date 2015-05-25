module Conversations::Twitter

  include Social::Dynamo::Twitter
  include Social::Twitter::ErrorHandler
  include Social::Constants

  def send_tweet_as_mention(ticket = @parent, note = @item, tweet_body = @tweet_body)
    current_account = Account.current
    reply_handle_id = reply_twitter_handle(ticket)
    @reply_handle = current_account.twitter_handles.find_by_id(reply_handle_id)
    twt = nil

    unless @reply_handle.nil?
      latest_comment = ticket.notes.latest_twitter_comment.first
      latest_tweet = latest_comment.nil? ? ticket.tweet : latest_comment.tweet
      status_id = latest_tweet.tweet_id

      tweet_params = {
        :body => tweet_body,
        :in_reply_to_id => status_id
      }
      error_msg, return_value = twt_sandbox(@reply_handle, TWITTER_TIMEOUT[:reply]) {
        twt = tweet_to_twitter(@reply_handle, tweet_params)

        #update dynamo
        unless latest_tweet.stream_id.blank?
          stream = current_account.twitter_streams.find_by_id(latest_tweet.stream_id)
          stream_id = "#{current_account.id}_#{latest_tweet.stream_id}"
          if stream && stream.default_stream?
            update_dynamo_for_tweet(twt, status_id, stream_id, note)
          elsif stream && stream.custom_stream?
            reply_params = agent_reply_params(twt, status_id, note)
            update_custom_streams_reply(reply_params, stream_id, note)
          end
        end

        process_tweet note, twt, reply_handle_id, :mention
      }
    end
    [error_msg, twt]
  end

  def send_tweet_as_dm(ticket = @parent, note = @item, tweet_body = @tweet_body)
    current_account = Account.current
    reply_handle_id = reply_twitter_handle(ticket)
    @reply_handle = current_account.twitter_handles.find_by_id(reply_handle_id)
    resp = nil

    unless @reply_handle.nil?
      latest_comment = ticket.notes.latest_twitter_comment.first
      latest_tweet = latest_comment.nil? ? ticket.tweet : latest_comment.tweet
      status_id = latest_tweet.tweet_id
      req_twt_id = latest_comment.nil? ? ticket.requester.twitter_id : latest_comment.user.twitter_id

      error_msg, return_value = twt_sandbox(@reply_handle, TWITTER_TIMEOUT[:reply]) {
        twitter  = TwitterWrapper.new(@reply_handle).get_twitter
        msg_body = tweet_body
        resp = twitter.create_direct_message(req_twt_id, msg_body)

        #update dynamo
        unless latest_tweet.stream_id.nil?
          stream_id = "#{current_account.id}_#{latest_tweet.stream_id}"
          reply_params = {
            :id => resp.attrs[:id_str],
            :user_id => resp.attrs[:recipient_id_str],
            :body => resp.attrs[:text],
            :posted_at => resp.attrs[:created_at]
          }
          update_dm(stream_id, reply_params)
        end

        process_tweet note, resp, reply_handle_id, :dm
      }
    end
    [error_msg, resp]
  end

  def tweet_to_twitter(handle, tweet_params )
    twitter =  TwitterWrapper.new(handle).get_twitter
    in_reply_to_id = tweet_params[:in_reply_to_id]
    twt = twitter.update(tweet_params[:body], {:in_reply_to_status_id => in_reply_to_id})
  end

  def update_dynamo_for_tweet(twt, status_id, stream_id, note)
    reply_params = agent_reply_params(twt, status_id, note)
    update_brand_streams_reply(stream_id, reply_params, note)
  end

  def agent_reply_params(twt, status_id, note)
    reply_params = {
      :id => twt.attrs[:id_str],
      :in_reply_to_user_id => twt.attrs[:in_reply_to_user_id_str],
      :body => twt.attrs[:text],
      :in_reply_to_id => "#{status_id}",
      :posted_at => twt.attrs[:created_at],
      :user => {
        :name => twt.attrs[:user][:name],
        :screen_name => twt.attrs[:user][:screen_name],
        :image => twt.attrs[:user][:profile_image_url]
      },
      :agent_name => note.nil? ? current_user.name : note.user.name
    }
  end

  protected

    def reply_twitter_handle ticket
      params[:twitter_handle].present? ? params[:twitter_handle] : ticket.fetch_twitter_handle
      #params.key?(:twitter_handle)
    end

    def process_tweet note, twt, handle_id, twt_type
      stream_id = @reply_handle.default_stream_id
      note.create_tweet({
        :tweet_id => twt.id,
        :tweet_type => twt_type.to_s,
        :twitter_handle_id => handle_id,
        :stream_id => stream_id
       })
    end

end
