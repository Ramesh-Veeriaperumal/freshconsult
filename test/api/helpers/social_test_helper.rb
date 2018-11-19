module SocialTestHelper

  def fb_dm_pattern(expected_output = {}, fb_post)
    ret_hash = {
      id: Fixnum,
      post_id: expected_output[:post_id] || fb_post.post_id,
      msg_type: expected_output[:msg_type] || fb_post.msg_type,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    ret_hash.merge!(fb_page: fb_page_pattern(fb_post)) if ['Helpdesk::Ticket'].include?(fb_post.postable_type)
    ret_hash
  end

  def fb_post_pattern(expected_output = {}, fb_post)
    post_attributes_hash = {
        post_type: expected_output[:post_type] || fb_post.post_attributes[:post_type],
        can_comment?: expected_output[:can_comment] || fb_post.post_attributes[:can_comment]
    }
    fb_dm_pattern(expected_output, fb_post).merge(post_attributes_hash)
  end

  def fb_page_pattern(fb_post)
    page = fb_post.facebook_page
    {
      id: page.id,
      profile_id: page.profile_id,
      page_id: page.page_id,
      page_name: page.page_name,
      page_image_url: page.page_img_url,
      page_link: page.page_link,
      enable_page: page.enable_page,
      product_id: page.product_id
    }
  end

  def fb_public_dm_pattern(expected_output = {}, fb_post)
    ret_hash = {
      id: expected_output[:post_id] || fb_post.post_id, # id will be post_id for public API
      type: expected_output[:msg_type] || fb_post.msg_type,
    }
    ret_hash.merge!(page: fb_public_page_pattern(fb_post, expected_output)) if ['Helpdesk::Ticket'].include?(fb_post.postable_type)
  end

  def fb_public_post_pattern(expected_output = {}, fb_post)
    post_attributes_hash = {}
    post_attributes_hash[:post_type] = Facebook::Constants::CODE_TO_POST_TYPE[expected_output[:post_type] || fb_post.post_attributes[:post_type]] 

    fb_public_dm_pattern(expected_output, fb_post).merge(post_attributes_hash)
  end

  def fb_public_page_pattern(fb_post, expected_output)
    page = fb_post.facebook_page
    {
      id: page.page_id,
      name: page.page_name,
      image_url: page.page_img_url,
      link: page.page_link,
      profile_id: page.profile_id,
      product_id: page.product_id
    }
  end

  def create_facebook_page(populate_streams = false)
    fb_page = FactoryGirl.build(:facebook_pages, :account_id => @account.id)
    Social::FacebookPage.any_instance.stubs(:check_subscription).returns({:data => []}.to_json)
    fb_page.save
    fb_page.update_attributes(:import_visitor_posts => true)
    if populate_streams
      fb_page.account.make_current
      fb_page.build_default_streams
    end
    Social::FacebookPage.any_instance.unstub(:check_subscription)
    fb_page
  end

  def create_ticket_from_fb_post(comments = false, reply_to_comments = false)
    #create a facebook page, comment on it, convert comment to ticket and populate the user
    Sidekiq::Testing.inline! do
      fb_page = create_facebook_page(true)
      feed_id    = "#{fb_page.page_id}_#{get_social_id}"
      comment_id = comments || reply_to_comments ? "#{feed_id.split('_').last}_#{get_social_id}" : nil
      reply_comment_id = reply_to_comments ? "#{feed_id.split('_').last}_#{get_social_id}" : nil
      sender_id  = "#{get_social_id}"
      facebook_feed = sample_fb_post_feed(sender_id, feed_id, comment_id, reply_comment_id)
      #stub the api call for koala
      Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
      Facebook::Core::Post.new(fb_page.reload, feed_id).process
      Koala::Facebook::API.any_instance.unstub(:get_object)
      @account.facebook_posts.find_by_post_id(feed_id).postable
    end
  end

  def create_ticket_from_fb_direct_message
    Sidekiq::Testing.inline! do
      fb_page = create_facebook_page(true)
      # todo find the root cause and fix it
      sleep(1)
      thread_id = Time.now.utc.to_i
      actor_id = thread_id + 1
      msg_id = thread_id + 2
      sample_dm = sample_dm_threads(thread_id, actor_id, msg_id)
      #stub the api call for koala
      Koala::Facebook::API.any_instance.stubs(:get_connections).returns(sample_dm)
      fb_message = Facebook::KoalaWrapper::DirectMessage.new(fb_page)
      fb_message.fetch_messages
      Koala::Facebook::API.any_instance.unstub(:get_connections)
      postable = @account.facebook_posts.find_by_post_id(msg_id).postable
      postable.is_a?(Helpdesk::Ticket) ? postable : postable.notable
    end
  end

  def sample_fb_post_feed(sender_id, feed_id, comment_id = nil, reply_comment_id = nil)
    fb_feed = {
      "id"   => "#{feed_id}",
      "type" => "post",
      "from" => {
        "name" => "Socio Paul",
        "id"   => "#{sender_id}"
      },
      "message"     => "#{Faker::Lorem.words(10).join(" ")}",
      "created_time"=> "#{Time.zone.now}"
    }

    unless comment_id.nil?
      comments = {
          "data" => [
            {
              "id"   => "#{comment_id}",
              "from" => {
                "name" => "#{Faker::Lorem.words(1)}",
                "id"   => "#{get_social_id}"
              },
              "can_comment"  => true,
              "created_time" => "#{Time.zone.now}",
              "message"      => "#{Faker::Lorem.words(10).join(" ")}"
            }
          ]
        }
      fb_feed.merge!({"comments" => comments})
    end

    unless reply_comment_id.nil?
      reply_comment = {
        "id"   => "#{reply_comment_id}",
        "from" => {
          "name" => "#{Faker::Lorem.words(1)}",
          "id"   => "#{get_social_id}"
        },
        "can_comment"  => false,
        "created_time" => "#{Time.zone.now}",
        "message"      => "#{Faker::Lorem.words(10).join(" ")}",
        "parent"       => fb_feed["comments"]["data"][0].dup
      }
      fb_feed["comments"]["data"].push(reply_comment)
    end
    fb_feed
  end

  def sample_dm_threads(thread_id, actor_id, msg_id)
    dm = [{
        "id"   => "#{thread_id}",
        "updated_time" => "#{Time.zone.now}",
        "messages" => {
          "data" => [
              {
                "id" => "#{msg_id}",
                "message" => "#{Faker::Lorem.words(10).join(" ")}",
                "from" => {
                  "name" => "#{Faker::Lorem.words(1)}",
                  "id" => "#{actor_id}"
                },
                "created_time" => "#{Time.zone.now}"
              }
          ]
        }
      },
      {
        "id"   => "#{thread_id}",
        "updated_time" => "#{Time.zone.now}",
        "messages" => {
          "data" => [
              {
                "id" => "#{msg_id + 2}",
                "message" => "#{Faker::Lorem.words(10).join(" ")}",
                "from" => {
                  "name" => "#{Faker::Lorem.words(1)}",
                  "id" => "#{actor_id}"
                },
                "created_time" => "#{Time.zone.now}"
              }
          ]
        }
      }]
  end

  def get_social_id
    (Time.now.utc.to_f*1000000).to_i
  end


  def tweet_pattern(expected_output = {}, tweet)
    {
      tweet_id: expected_output[:tweet_id] || "#{tweet.tweet_id}",
      tweet_type: expected_output[:tweet_type] || tweet.tweet_type,
      twitter_handle_id: expected_output[:twitter_handle_id] || tweet.twitter_handle_id
    }
  end

end
