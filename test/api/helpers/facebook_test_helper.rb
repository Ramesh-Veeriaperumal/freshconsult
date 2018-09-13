module FacebookTestHelper
  def create_test_facebook_page(account = nil)
    account = create_test_account if account.nil?
    fb_page = FactoryGirl.build(:facebook_pages, account_id: account.id)
    fb_page.save
    fb_page
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
