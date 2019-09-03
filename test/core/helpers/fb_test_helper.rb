module FBTestHelper
  def create_post_note_with_negative_post_id(ticket)
    ticket.notes.build(body: Faker::Lorem.characters(100), user_id: @user.id)
    ticket.save!

    last_note = ticket.notes.last
    last_note.create_fb_post(
      post_id: negative_random_id,
      facebook_page_id: ticket.fb_post.facebook_page_id,
      account_id: ticket.account_id,
      parent_id: ticket.fb_post.id,
      post_attributes: {
        can_comment: false,
        post_type: 3 # reply to comment
      }
    )
    last_note.reload
  end

  def update_facebook_reply_state_command_payload(account, note, fb_page, stream_type = 'post')
    context = update_facebook_reply_state_context_payload(note, stream_type, fb_page)
    data = update_facebook_reply_state_success_data_payload(fb_page)

    options = {
      owner: 'facebook',
      client: 'helpkit',
      pod: ChannelFrameworkConfig['pod'],
      command_name: 'update_facebook_reply_state'
    }

    facebook_channel_payload('helpkit_command', account, options, context, data)
  end

  def update_facebook_reply_state_context_payload(note, stream_type, fb_page)
    {
      note: {
        id: note.id,
        created_at: note.created_at
      },
      facebook_data: {
        stream_type: stream_type,
        facebook_page_id: fb_page.id
      }
    }
  end

  def update_facebook_reply_state_success_data_payload(fb_page)
    {
      success: true,
      details: {
        facebook_item_id: "#{fb_page.page_id}_#{Faker::Number.number(15)}",
        posted_at: Time.now.utc
      }
    }
  end

  def update_facebook_reply_state_failure_data_payload
    {
      success: false,
      errors: {
        error_code: 190,
        error_message: 'Access token/Page token invalid'
      }
    }
  end

  def facebook_channel_payload(type, account, options, context, data)
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

  def negative_random_id
    -"#{Time.now.utc.to_i}#{rand(100...999)}".to_i
  end
end
