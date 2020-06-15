module ChannelReplyTestHelper
  def construct_facebook_response_payload(success = true, note_id = nil, errors = {})
    payload =
      {
        client: 'facebook',
        schema_version: 1,
        pod: 'development',
        context: {
          note_id: note_id
        },
        command_id: '57eb357f-aa60-422c-ab2c-280e068d6c3f',
        command_name: 'send_survey_facebook_dm',
        region: 'us-east-1',
        data: {
          success: success
        },
        reply_status: success ? 'success' : 'error',
        status_code: success ? 200 : errors[:error_code],
        reply_id: 'd49dfaa9-473b-43e8-b526-cec084887fc0'
      }
    payload[:data][:errors] = errors if errors.present?
    payload
  end

  def construct_twitter_reply_payload_with_error(note_id = 123)
    {
      owner: 'helpkit',
      client: 'twitter',
      schema_version: 1,
      account_id: '1',
      domain: 'https://angrynerds1nipun.freshpo.com',
      pod: 'staging',
      context: {
        tweet_type: 'dm',
        stream_id: 134,
        note_id: note_id,
        twitter_handle_id: 29
      },
      command_id: '736bcff9-5c21-49ae-8ae8-d0c83ccb33d3',
      command_name: 'send_survey_twitter_dm',
      region: 'us-east-1',
      data: {
        status_code: 403, message: 'User not found'
      },
      status_code: 403,
      reply_status: 'error',
      reply_id: '3f0f9bc0-62e2-4def-8c37-2cdf2ea41e6f'
    }
  end
end
