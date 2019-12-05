module Conversations::Twitter

  include Social::Twitter::ErrorHandler
  include Social::Constants

  def send_tweet_as_mention(handle_id, ticket, note, tweet_body, allow_attachments = false)
    current_account = Account.current
    reply_handle_id = handle_id || ticket.fetch_twitter_handle
    @reply_handle = current_account.twitter_handles.find_by_id(reply_handle_id)
    twt = nil

    unless @reply_handle.nil?
      latest_comment = ticket.notes.latest_twitter_comment.first
      latest_tweet = latest_comment.nil? ? ticket.tweet : latest_comment.tweet
      status_id = latest_tweet.tweet_id

      tweet_params = { body: tweet_body, in_reply_to_id: status_id}

      attachments = note.attachments
      if allow_attachments && attachments.present?
        attached_files = attachments.map do |attachment|
          attachment.fetch_from_s3
        end
        tweet_params[:attachment_files] = attached_files
      end

      error_msg, return_value, error_code = twt_sandbox(@reply_handle, TWITTER_TIMEOUT[:reply]) {
        twt = tweet_to_twitter(@reply_handle, tweet_params)

        #update dynamo
        unless latest_tweet.stream_id.blank?
          stream = current_account.twitter_streams.find_by_id(latest_tweet.stream_id)
          stream_id = "#{current_account.id}_#{latest_tweet.stream_id}"
          if stream && stream.default_stream?
            update_dynamo_for_tweet(twt, status_id, stream_id, note)
          elsif stream && stream.custom_stream?
            dynamo_helper = Social::Dynamo::Twitter.new
            reply_params = agent_reply_params(twt, status_id, note)
            dynamo_helper.update_custom_streams_reply(reply_params, stream_id, note)
          end
        end

        process_tweet note, twt, reply_handle_id, :mention
      }
    end
    [error_msg, twt, error_code]
  ensure
    clear_local_files(tweet_params[:attachment_files])
  end

  def send_tweet_as_dm(handle_id, ticket, note, tweet_body, allow_attachments = false)
    current_account = Account.current
    reply_handle_id = handle_id || ticket.fetch_twitter_handle
    @reply_handle = current_account.twitter_handles.find_by_id(reply_handle_id)
    resp = nil

    unless @reply_handle.nil?
      error_msg, return_value, error_code = twt_sandbox(@reply_handle, TWITTER_TIMEOUT[:reply]) do
        process_tweet(note, nil, reply_handle_id, :dm)
      end
    end
    [error_msg, resp, error_code]
  end

  def tweet_to_twitter(handle, tweet_params)
    twitter = TwitterWrapper.new(handle).get_twitter
    options = { in_reply_to_status_id: tweet_params[:in_reply_to_id] }
    if tweet_params[:attachment_files].present?
      media_ids = upload_media(twitter, tweet_params[:attachment_files])
      options[:media_ids] = media_ids.join(',')
    end
    twitter.update(tweet_params[:body], options)
  end

  def upload_media(twitter, files_to_upload)
    media_ids = files_to_upload.map do |file|
      twitter.upload(file)
    end
  end

  def clear_local_files(files)
    files.each do |file|
      file.close unless file.closed?
      File.delete(file)
    end
  end

  def update_dynamo_for_tweet(twt, status_id, stream_id, note)
    reply_params = agent_reply_params(twt, status_id, note)
    Social::Dynamo::Twitter.new.update_brand_streams_reply(stream_id, reply_params, note)
  end

  def agent_reply_params(twt, status_id, note)
    reply_params = {
      :id => twt.attrs[:id_str],
      :in_reply_to_user_id => twt.attrs[:in_reply_to_user_id_str],
      :body => twt.attrs[:text],
      :in_reply_to_id => "#{status_id}",
      :attachment_id => note.nil? ? [] : note.attachments.map(&:id),
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

    def process_tweet note, twt, handle_id, twt_type
      stream_id = @reply_handle.default_stream_id
      tweet_id = twt.present? ? twt.id : random_tweet_id

      note.create_tweet(tweet_id: tweet_id, tweet_type: twt_type.to_s, twitter_handle_id: handle_id, stream_id: stream_id)
    end

    def random_tweet_id
      -"#{Time.now.utc.to_i}#{rand(100...999)}".to_i
    end
end
