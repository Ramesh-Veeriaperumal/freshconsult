module FacebookTestHelper
  def create_test_facebook_page(account = nil)
    account = create_test_account if account.nil?
    fb_page = FactoryGirl.build(:facebook_pages, account_id: account.id)
    fb_page.save
    fb_page
  end

  def sample_dms(thread_id, user_id, msg_id, time)
    dm = [
      {
        'id' => thread_id.to_s,
        'updated_time' => Time.now.utc.to_s,
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
          ]
        }
      },
      {
        'id' => thread_id.to_s,
        'updated_time' => Time.now.utc.to_s,
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
          ]
        }
      }
    ]
  end

  def realtime_dms(page_id, msg_id, user_id, time)
    {
      'entry' => {
        'id' => page_id.to_s,
        'time' => time.to_i,
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

  def verify_ticket_properties(ticket, message)
    fb_user_id = message[:from][:id]
    dm_created_at = Time.zone.parse(message[:created_time])
    direct_message_content = message[:message]
    assert_equal ticket.description, direct_message_content 
    assert_equal ticket.source, Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:facebook] 
    assert_equal ticket.requester.fb_profile_id, fb_user_id 
    assert_equal ticket.created_at, dm_created_at
  end

  def verify_note_properties(note, message)
    fb_user_id = message[:from][:id]
    dm_created_at = Time.zone.parse(message[:created_time])
    direct_message_content = message[:message]
    assert_equal note.body, direct_message_content 
    assert_equal note.source, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['facebook'] 
    assert_equal note.user.fb_profile_id, fb_user_id  
    assert_equal note.created_at, dm_created_at
  end

  def create_facebook_dm_as_ticket(fb_page, thread_id, user_id)
    msg_id = rand(10**10)
    time = Time.now.utc

    dm = sample_dms(thread_id, user_id, msg_id, time)
    dm.pop
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(dm)
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

  def sample_realtime_post(page_id, post_id, user_id, time)
    {
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
    }
  end

  def sample_realtime_comment(page_id, post_id, comment_id, user_id, time)
    {
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
                'parent_id' => "#{@fb_page.page_id}_#{post_id}",
                'created_time' => Time.now.utc.to_i,
                'is_hidden' => false
              }
            }
          ],
          'id' => page_id.to_s,
          'time' => time.to_i
        },
      'object' => 'page'
    }
  end
end
