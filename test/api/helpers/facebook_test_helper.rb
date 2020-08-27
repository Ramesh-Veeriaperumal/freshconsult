module FacebookTestHelper
  def create_test_facebook_page(account = nil)
    account = create_test_account if account.nil?
    fb_page = FactoryGirl.build(:facebook_pages, account_id: account.id, page_name: Faker::Name.name)
    Social::FacebookPage.any_instance.stubs(:check_subscription).returns({:data => []}.to_json)
    fb_page.save
    Social::FacebookPage.any_instance.unstub(:check_subscription)
    fb_page
  end

  def sample_dms(thread_id, user_id, msg_id, time)
    {
      'data' => [
        {
          'id' => thread_id.to_s,
          'updated_time' => time.to_s,
          'messages' => {
            'data' => [
              {
                'id' => msg_id.to_s,
                'message' => Faker::Lorem.words(10).join(' ').to_s,
                'from' => {
                  'name' => Faker::Lorem.words(1).to_s,
                  'id' => user_id.to_s
                },
                'created_time' => time.to_s
              }
            ],
            'paging' => {
              'cursors' => {
                'after' => Faker::Lorem.word
              }
            }
          }
        }, {
          'id' => thread_id.to_s,
          'updated_time' => time.to_s,
          'messages' => {
            'data' => [
              {
                'id' => (msg_id + 5).to_s,
                'message' => Faker::Lorem.words(10).join(' ').to_s,
                'from' => {
                  'name' => Faker::Lorem.words(1).to_s,
                  'id' => user_id.to_s
                },
                'created_time' => (time + 1.hour).to_s
              }
            ],
            'paging' => {
              'cursors' => {
                'after' => Faker::Lorem.word
              }
            }
          }
        }
      ],
      'paging' => {
        'cursors' => {
          'after' => Faker::Lorem.word
        }
      }
    }
  end

  def realtime_dms(page_id, msg_id, user_id, time)
    {
      'entry' => {
        'id' => page_id.to_s,
        'time' => time.to_i,
        'account_id' => @account.id,
        'pod' => ChannelFrameworkConfig['pod'],
        'region' => 'us-east-1',
        'messaging' => [
          {
            'sender' => {
              'id' => user_id.to_s
            },
            'recipient' => {
              'id' => page_id.to_s
            },
            'timestamp' => time.to_i,
            'message' => {
              'mid' => msg_id.to_s
            }
          },
          {
            'sender' => {
              'id' => user_id.to_s
            },
            'recipient' => {
              'id' => page_id.to_s
            },
            'timestamp' => (time + 1.hour).to_i,
            'message' => {
              'mid' => (msg_id + 5).to_s
            }
          }
        ]
      }
    }
  end

  def sample_echo_message_fb_response(msg_id, user_id, page_id, time)
    {
      id: msg_id.to_s,
      message: Faker::Lorem.words(10).join(' ').to_s,
      from: {
        name: Faker::Lorem.words(1).to_s,
        id: page_id.to_s
      },
      to: {
        data: [
          {
            id: user_id.to_s,
            name: Faker::Name.name
          }
        ]
      },
      created_time: time.to_s
    }
  end

  def verify_ticket_properties(ticket, message, is_echo = false)
    fb_user_id = is_echo ? message[:to][:data].first[:id] : message[:from][:id]
    dm_created_at = Time.zone.parse(message[:created_time])
    direct_message_content = message[:message]
    assert_equal ticket.description, direct_message_content 
    assert_equal ticket.source, Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook] 
    assert_equal ticket.requester.fb_profile_id, fb_user_id 
    assert_equal ticket.created_at, dm_created_at
  end

  def verify_note_properties(note, message, is_echo = false)
    fb_user_id = is_echo ? message[:to][:data].first[:id] : message[:from][:id]
    dm_created_at = Time.zone.parse(message[:created_time])
    direct_message_content = message[:message]
    assert_equal note.body, direct_message_content 
    assert_equal note.source, Account.current.helpdesk_sources.note_source_keys_by_token['facebook'] 
    assert_equal note.user.fb_profile_id, fb_user_id  
    assert_equal note.created_at, dm_created_at
  end

  def create_facebook_dm_as_ticket(fb_page, thread_id, user_id)
    msg_id = rand(10**10)
    time = Time.now.utc

    dm = sample_dms(thread_id, user_id, msg_id, time)
    dm['data'].pop
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(dm.to_json)
    fb_message = Facebook::KoalaWrapper::DirectMessage.new(fb_page)
    fb_message.fetch_messages
    Koala::Facebook::API.any_instance.unstub(:get_connections)
  end


  def sample_post_feed(page_id, user_id, feed_id, time)
    fb_feed = [{
      'id'   => "#{page_id}_#{feed_id}",
      'type' => 'post',
      'from' => {
        'name' => Faker::Lorem.words(1).to_s,
        'id'   => user_id.to_s
      },
      'message' => Faker::Lorem.words(10).join(' ').to_s,
      'created_time' => time.to_s,
      'updated_time' => Time.now.utc.to_s
    }]
  end

  def sample_cover_photo_feed(page_id, user_id, feed_id, time, message)
    fb_feed = [{
      'id'   => "#{feed_id}_#{page_id}",
      'type' => 'cover_photo',
      'from' => {
        'name' => Faker::Lorem.words(1).to_s,
        'id'   => user_id.to_s
      },
      'message' => message,
      'created_time' => time.to_s,
      'updated_time' => Time.now.utc.to_s
    }]
  end

  def sample_comment_feed(post_id, user_id, comment_id, time)
    comments = {
      'data' => [
        'id'   => "#{post_id}_#{comment_id}",
        'from' => {
          'name' => Faker::Lorem.words(1).to_s,
          'id'   => user_id.to_s
        },
        'can_comment'  => true,
        'created_time' => time.to_s,
        'message'      => "Support #{Faker::Lorem.words(20).join(' ')}"
      ]
    }
  end

  def sample_comment_feed_with_mentions(post_id, user_id, comment_id, time)
    comments = {
      'data' => [
        'id'   => "#{post_id}_#{comment_id}",
        'from' => {
          'name' => Faker::Lorem.words(1).to_s,
          'id'   => user_id.to_s
        },
        'can_comment'  => true,
        'created_time' => time.to_s,
        'message'      => 'tags',
        'message_tags' => [{ 'name' => 'tags' }]
      ]
    }
  end

  def sample_comment_feed_with_mentions_and_emojis(post_id, user_id, comment_id, time)
    comments = {
      'data' => [
        'id'   => "#{post_id}_#{comment_id}",
        'from' => {
          'name' => Faker::Lorem.words(1).to_s,
          'id'   => user_id.to_s
        },
        'can_comment'  => true,
        'created_time' => time.to_s,
        'message'      => 'emojis😁😃',
        'message_tags' => [{ 'name' => 'emojis' }]
      ]
    }
  end

  def sample_comment_feed_with_multiple_mentions(post_id, user_id, comment_id, time)
    comments = {
      'data' => [
        'id'   => "#{post_id}_#{comment_id}",
        'from' => {
          'name' => Faker::Lorem.words(1).to_s,
          'id'   => user_id.to_s
        },
        'can_comment'  => true,
        'created_time' => time.to_s,
        'message'      => 'tags messages',
        'message_tags' => [
          { 'name' => 'tags' },
          { 'name' => 'messages' }
        ]
      ]
    }
  end

  def sample_realtime_post(page_id, post_id, user_id, time)
    wrap_central_payload({
      'entry' =>
        {
          'changes' => [
            {
              'field' => 'feed',
              'value' => {
                'from' => {
                  'id' => user_id.to_s
                },
                'item' => 'post',
                'post_id' => post_id.to_s,
                'verb' => 'add',
                'created_time' => Time.now.utc.to_i,
                'is_hidden' => false
              }
            }
          ],
          'id' => page_id.to_s,
          'time' => time.to_i
        },
      'object' => 'page'
    })
  end

  def sample_realtime_comment(page_id, post_id, comment_id, user_id, time, parent_id = nil)
    wrap_central_payload({
      'entry' =>
        {
          'changes' => [
            {
              'field' => 'feed',
              'value' => {
                'from' => {
                  'id' => user_id.to_s
                },
                'item' => 'comment',
                'comment_id' => "#{post_id}_#{comment_id}",
                'post_id' => "#{@fb_page.page_id}_#{post_id}",
                'verb' => 'add',
                'parent_id' => parent_id ? "#{@fb_page.page_id}_#{parent_id}" : "#{@fb_page.page_id}_#{post_id}",
                'created_time' => Time.now.utc.to_i,
                'is_hidden' => false
              }
            }
          ],
          'id' => page_id.to_s,
          'time' => time.to_i
        },
      'object' => 'page'
    })
  end


  def wrap_central_payload(payload)
    {
      'meta': {},
      'data': {
        'payload_type': 'facebook_realtime_feeds',
        'payload': payload,
        'account_id': @account.id,
        'pod': ChannelFrameworkConfig['pod'],
        'region': 'us-east-1'
      },
      'entry': {
        'account_id': @account.id,
        'pod': ChannelFrameworkConfig['pod'],
        'region': 'us-east-1'
      }
    }
  end
end
