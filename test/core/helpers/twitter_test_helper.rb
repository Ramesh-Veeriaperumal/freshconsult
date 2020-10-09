module TwitterTestHelper
  def create_test_twitter_handle(account)
    handle = FactoryGirl.build(:twitter_handle, account_id: account.id)
    handle.capture_mention_as_ticket = 1
    handle.save!
    handle.reload
    handle
  end

  def cleanup_twitter_handles(account)
    account.twitter_handles.delete_all
    account.tickets.where(source: 5).destroy_all
  end

  def stub_twitter_attachments_hash(media_url)
    { photo: { 'https://pbs.twimg.com/media/HsEgj7f3jhgWDR.jpg' => 'https://attachmenttestlink.com' }, twitter_url: media_url }
  end

  def sample_gnip_feed(account, stream, reply = false, media_url = nil, time = Time.now.utc.iso8601)
    tweet_id = (Time.now.utc.to_f * 1_000_000).to_i
    feed_hash = {
      'body' => "@TestingGnip #{Faker::Lorem.words(20).join(' ')}",
      'retweetCount' => 2,
      'gnip' => {
        'matching_rules' => [{
          'tag' => "S#{stream.id}_#{account.id}",
          'value' => '@TestingGnip'
        }],
        'klout_score' => '0'
      },
      'actor' => {
        'preferredUsername' => 'GnipTestUser',
        'image' => 'https://si0.twimg.com/profile_images/123134/db88b820451fa8498e8f3cf406675e13_normal.png',
        'id' => "id:twitter.com:#{tweet_id}",
        'displayName' => 'Gnip Test User'
      },
      'verb' => 'post',
      'postedTime' => time,
      'id' => "tag:search.twitter.com,2005:#{tweet_id}"
    }

    if reply
      feed_hash['inReplyTo'] = {
        'link' => "http://twitter.com/TestingGnip/statuses/#{reply}"
      }
    end

    unless media_url.nil?
      feed_hash['body'] = feed_hash['body'] + " #{media_url}"
      feed_hash['twitter_extended_entities'] = {
        'media' => [
          {
            'id' => 1_018_440_700_340_211_700,
            'id_str' => '1018440700340211712',
            'media_url' => 'http://pbs.twimg.com/media/HsEgj7f3jhgWDR.jpg',
            'media_url_https' => 'https://pbs.twimg.com/media/HsEgj7f3jhgWDR.jpg',
            'url' => media_url,
            'display_url' => 'pic.twitter.com/testingurl',
            'expanded_url' => "https://twitter.com/TestingGnip/status/#{tweet_id}/photo/1",
            'type' => 'photo'
          }
        ]
      }
    end
    feed_hash
  end

  def sample_twitter_create_ticket_command(account, handle, stream, options = {})
    context = get_command_context(handle, stream, options)
    data = {
      "subject": options[:subject] || 'Sample Subject',
      "requester_id": options[:requester_id],
      "description": options[:description],
      "source": 5,
      "created_at": options[:created_at] || '2015-07-09T13:08:06Z',
      "twitter_profile_status": true,
      "twitter_followers_count": 49
    }
    options = {
      owner: 'twitter',
      client: 'helpkit',
      pod: ChannelFrameworkConfig['pod'],
      command_name: 'create_ticket'
    }

    channel_payload('helpkit_command', account, options, context, data)
  end

  def sample_twitter_create_note_command(account, handle, stream, options = {})
    context = get_command_context(handle, stream, options)
    data = {
      "user_id": options[:user_id],
      "ticket_id": options[:ticket_id],
      "body": options[:body],
      "source": 5,
      "private": true,
      "created_at": options[:created_at] || '2015-07-09T13:08:06Z',
      "twitter_profile_status": true,
      "twitter_followers_count": 49
    }
    options = {
      owner: 'twitter',
      client: 'helpkit',
      pod: ChannelFrameworkConfig['pod'],
      command_name: 'create_note'
    }

    channel_payload('helpkit_command', account, options, context, data)
  end

  def sample_twitter_reply_acknowledgement(account, handle, stream, options = {})
    context = get_command_context(handle, stream, options)
    context[:note_id] = options[:note_id]

    data = {}
    data[:status_code] = options[:status_code]
    data[:code] = options[:code]
    data[:tweet_id] = options[:tweet_id] if options[:tweet_id].present?

    options = {
      owner: 'twitter',
      client: 'helpkit',
      pod: ChannelFrameworkConfig['pod'],
      command_name: 'update_twitter_message'
    }

    channel_payload('helpkit_command', account, options, context, data)
  end

  def get_command_context(handle, stream, options = {})
    {
      "stream_id": stream.id,
      "tweet_id": options[:tweet_id] || '1005',
      "tweet_type": options[:tweet_type] || 'dm',
      "twitter_handle_id": handle.twitter_user_id,
      "contact_twitter_user_id": options[:contact_twitter_user_id] || Faker::Number.between(1, 999_999_999).to_s,
      "twitter_screen_name": options[:twitter_screen_name]
    }
  end

  def channel_payload(type, account, options, context, data)
    {
      "msg_id": SecureRandom.uuid,
      "payload_type": type,
      "account_id": account.id,
      "payload": {
        "owner": options[:owner],
        "client": options[:client],
        "account_id": account.id,
        "domain": "https://#{account.full_domain}",
        "pod": options[:pod],
        "context": context,
        "data": data,
        "meta": {
          "fallbackToReplyQueue": false,
          "timeout": 30_000,
          "waitForReply": false
        },
        "command_name": options[:command_name],
        "command_id": SecureRandom.uuid,
        "schema_version": 1
      }
    }
  end

  def conflict_reply_payload(entity_id, tweet_id)
    {
      data: {
        message: "Conflict: Tweet ID: #{tweet_id} already converted.",
        id: entity_id
      },
      status_code: 409,
      reply_status: 'error'
    }
  end

  def blocked_user_reply_payload
    {
      data: {
        message: ErrorConstants::ERROR_MESSAGES[:user_blocked_error]
      },
      status_code: Social::Constants::TWITTER_ERROR_CODES[:user_blocked_error],
      reply_status: 'error'
    }
  end

  def ticket_archived_error_payload(ticket_id)
    {
        data: {
          message: Social::Constants::TICKET_ARCHIVED,
          ticket_id: ticket_id
        },
        status_code: Social::Constants::TWITTER_ERROR_CODES[:archived_ticket_error],
        reply_status: 'error'
    }
  end
end
