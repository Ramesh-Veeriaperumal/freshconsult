module SocialTestHelper

  def fb_dm_pattern(expected_output = {}, fb_post)
    {
      id: Fixnum,
      post_id: expected_output[:post_id] || fb_post.post_id,
      msg_type: expected_output[:msg_type] || fb_post.msg_type,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end
  
  def fb_post_pattern(expected_output = {}, fb_post)
    post_attributes_hash = {
        post_type: expected_output[:post_type] || fb_post.post_attributes[:post_type],
        can_comment?: expected_output[:can_comment] || fb_post.post_attributes[:can_comment]
    }
    fb_dm_pattern(expected_output, fb_post).merge(post_attributes_hash)
  end

  def create_facebook_page(populate_streams = false)
    fb_page = FactoryGirl.build(:facebook_pages, :account_id => @account.id)
    fb_page.save
    fb_page.update_attributes(:import_visitor_posts => true)
    if populate_streams
      fb_page.account.make_current
      fb_page.build_default_streams
    end
    fb_page
  end

  def create_ticket_from_fb_post(comments = false, reply_to_comments = false)
    #create a facebook page, comment on it, convert comment to ticket and populate the user
    Sidekiq::Testing.inline!
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

  def create_ticket_from_fb_direct_message
    Sidekiq::Testing.inline!
    fb_page = create_facebook_page(true)
    thread_id = Time.now.utc.to_i
    actor_id = thread_id + 1
    msg_id = thread_id + 2
    sample_dm = sample_dm_threads(thread_id, actor_id, msg_id)
    #stub the api call for koala
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(sample_dm)
    fb_message = Facebook::KoalaWrapper::DirectMessage.new(fb_page)
    fb_message.fetch_messages
    Koala::Facebook::API.any_instance.unstub(:get_connections)
    @account.facebook_posts.find_by_post_id(msg_id).postable
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
end
