module Social::Twitter::CentralUtil
  include ChannelIntegrations::Utils::Schema

  def construct_payload(error_message, reply_twt, error_code, stream_id, args)
    payload = default_command_schema('helpkit', Social::Twitter::Constants::STATUS_UPDATE_COMMAND_NAME)
    payload[:owner] = 'twitter'
    payload[:data] = if error_message.present?
                       construct_error_command_data(error_message, error_code)
                     else
                       {
                         status: 200,
                         tweet_id: reply_twt
                       }
                     end
    payload[:context] = construct_command_context(args[:tweet_type], args[:twitter_handle_id], args[:note_id], stream_id)
    payload
  end

  def construct_error_command_data(error_message, error_code)
    {
      status: error_code || 0,
      message: error_message,
      code: error_code || 0
    }
  end

  def construct_command_context(tweet_type, twitter_handle_id, note_id, stream_id)
    {
      tweet_type: tweet_type,
      stream_id: stream_id,
      note_id: note_id,
      twitter_handle_id: twitter_handle_id
    }
  end

  def generate_msg_id(payload)
    Digest::MD5.hexdigest(payload.to_s)
  end
end
