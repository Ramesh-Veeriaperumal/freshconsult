require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module FacebookHelper
  
  def create_test_facebook_page(account = nil)
    account = create_test_account if account.nil?
    fb_page = Factory.build(:facebook_pages, :account_id => account.id)
    fb_page.save
    fb_page
  end
  
  def sample_realtime_feed(feed_id, clazz = "post")
    realtime_feed = {
      "entry" => {
          "id" => "#{@fb_page.page_id}",
          "time" => 1374146491,
          "changes" => [{
              "field" => "feed", 
              "value" => { 
                    "item" => "#{clazz}", 
                    "verb" => "add", 
                    "post_id" => "#{feed_id}"
                  }
                }]
        }
    }
    realtime_feed.to_json
  end
  
  def sample_realtime_comment_feed(feed_id)
    realtime_feed = {
      "entry" => {
          "id" => "#{@fb_page.page_id}",
          "time" => 1374146491,
          "changes" => [{
              "field" => "feed", 
              "value" => { 
                    "item" => "comment", 
                    "verb" => "add", 
                    "comment_id" => "#{feed_id}"
                  }
                }]
        }
    }
    realtime_feed.to_json
  end
  
  def sample_facebook_feed(feed_id, comments = false, reply_to_comments = false, status = false)
    page_id = status ? "#{feed_id.split('_').first}" : "#{(Time.now.utc.to_f*100000).to_i}"
    post_id = "#{feed_id.split('_').second}"
    fb_feed = {
      "id" => "#{feed_id}", 
      "from" => {
        "category" => "Community", 
        "name" => "Helloworld", 
        "id" => page_id
      }, 
      "type" => "photo",
      "picture" => "https://m.ak.fbcdn.net/sphotos-g.ak/hphotos-ak-xfa1/t1.0-9/p130x130/10492286_721289617907155_8502196072433838871_n.png",
      "link" => "https://www.facebook.com/617864998249618/photos/a.632203713482413.1073741826.617864998249618/721289617907155/?type=1&relevant_count=1", 
      "icon" => "https://m-static.ak.fbcdn.net/rsrc.php/v2/yz/r/StEh3RhPvjk.gif",
      "message" => "facebook post", 
      "privacy" => {
        "value" => ""
      }, 
      "type" => "status", 
      "status_type" =>  "mobile_status_update", 
      "created_time" => "2014-04-28T12:06:36+0000", 
      "updated_time" => "2014-04-28T12:06:36+0000"
    }
    
    fb_feed.symbolize_keys!
    if comments
      comments = sample_comment_feed(page_id, post_id, "Testing Comment")
      fb_feed.merge!(comments.symbolize_keys!)
    end
    
    if reply_to_comments
      reply_to_comments = sample_comment_feed(page_id, post_id, "Testing Reply to Comment")
      parent = {
        "parent" => {
                "id" => "#{fb_feed[:comments]["data"].first["id"]}", 
                "from" => {
                  "category" => "Community", 
                  "name" => "Helloworld", 
                  "id" => "617864998249618"
                } 
          }
      }
      reply_to_comments.symbolize_keys!
      reply_to_comments[:comments]["data"].first.merge!(parent)
      fb_feed[:comments]["data"].first.merge!(reply_to_comments.symbolize_keys!)
    end
    
    fb_feed   
  end
  
  def sample_comment_feed(page_id, post_id, message = "Test message")
    {
        "comments" => {
          "data" => [
            {
              "id" => "#{post_id}_#{Random.rand(1000..9999)}", 
              "from" => {
                "category" => "Community", 
                "name" => "Helloworld", 
                "id" => "#{page_id}"
              }, 
              "message" => "#{message}", 
              "can_remove" => true, 
              "created_time" => "2014-04-29T05:59:59+0000", 
              "like_count" => 0, 
              "user_likes" =>  false
            }
          ]
        }
    }
  end
  
  def sample_facebook_comment_feed(page_id, post_id, message = "Test message", reply_to_comments = false, comment_id = nil)
    comment = {
      "id" => "#{post_id}_#{(Time.now.utc.to_f*100000).to_i}", 
      "from" => {
        "category" => "Community", 
        "name" => "Helloworld", 
        "id" => "#{page_id}"
      }, 
      "message" => "#{message}", 
      "can_remove" => true, 
      "created_time" => "2014-04-29T05:59:59+0000", 
      "like_count" => 0, 
      "user_likes" =>  false
    }
    if reply_to_comments
      parent = {
        "parent" => {
                "id" => "#{comment_id}", 
                "from" => {
                  "category" => "Community", 
                  "name" => "Helloworld", 
                  "id" => "617864998249618"
                } 
          }
      }
      comment.merge!(parent)
    end
    comment.symbolize_keys!
  end
  
  
  def sample_post_and_ticket
    post_id = "#{@fb_page.page_id}_#{(Time.now.utc.to_f*100000).to_i}"
    realtime_feed = sample_realtime_feed(post_id)
    facebook_feed = sample_facebook_feed(post_id)
    
    #stub the api call for koala
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(facebook_feed)
    
    Facebook::Core::Parser.new(realtime_feed).parse
    
    post = Social::FbPost.find_by_post_id(post_id)
    post.should_not be_nil
    post.is_ticket?.should be_true
    
    ticket = post.postable
    user_id = @account.users.find_by_fb_profile_id(facebook_feed[:from][:id]).id
    ticket.description.should eql facebook_feed[:message]
    ticket.subject.should eql truncate_subject(facebook_feed[:message], 100)
    ticket.requester_id.should eql user_id
    [ticket, post_id]
  end
  
   def sample_user_profile(profile_id)
     name = Faker::Name.name
     { "id" => profile_id, 
       "email" => Faker::Internet.email(name.split.last),  
       "name" => "#{name}", 
       "username" => Faker::Internet.user_name(name.split.last),
       "verified"=>true
     }
   end
  
  def sample_fql_feed(feed_id, status = true, comment_count = 0)
    actor_id = status ? @fb_page.page_id : (Time.now.utc.to_f*100000).to_i
    [
      {
        "post_id" =>  "#{feed_id}", 
        "message" => Faker::Lorem.sentence(3), 
        "actor_id" => "#{actor_id}", 
        "updated_time" => (Time.now.utc.to_f).to_i, 
        "created_time" => (Time.now.utc.to_f).to_i,
        "comments" => {
          "can_remove" => true, 
          "can_post" => true, 
          "count" => comment_count, 
          "comment_list" => [
          ]
        }
      }
    ]
  end
  
  def sample_fql_comment(post_id, comment_id)
    [
        {
          "id" => "#{comment_id}", 
          "post_fbid" => "#{post_id}.split('_').last", 
          "post_id" => "#{post_id}", 
          "text" => "COMMENT FQL TEXT", 
          "time" => 1402580105, 
          "fromid" => "617864998249618"
        }
    ]
  end
  
  def sample_fql_comment_feed(post_id)
    [
      {
        "id" => "#{post_id.split("_").last}_#{(Time.now.utc.to_f * 1000).to_i}",
        "from" => {
          "category" =>  Faker::Lorem.sentence(1), 
          "name" => Faker::Lorem.sentence(1), 
          "id" => (Time.now.utc.to_f * 1000).to_i
        }, 
        "message" => Faker::Lorem.sentence(3),
        "can_remove" => true, 
        "created_time" => Time.now.utc.iso8601, 
        "like_count" => 0, 
        "user_likes" => false
      }
    ]
  end
  
  def sample_comment_and_ticket
    data = @default_stream.data.merge({:replies_enabled => true})
    @default_stream.update_attributes(:data => data)

    comment = sample_facebook_comment_feed(@fb_page.page_id, "#{(Time.now.utc.to_f*100000).to_i}", "Comment to post on facebook")
    comment_id = comment[:id]
    realtime_feed = sample_realtime_comment_feed(comment_id)
   
    
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(comment)
    
    Facebook::Core::Parser.new(realtime_feed).parse
    
    user_id = @account.users.find_by_fb_profile_id(comment[:from][:id]).id
    post_comment = Social::FbPost.find_by_post_id(comment[:id])
    
    
    post_comment.should_not be_nil
    post_comment.is_ticket?.should be_true
    
    ticket = post_comment.postable
    user_id = @account.users.find_by_fb_profile_id(comment[:from][:id]).id
    ticket.description.should eql comment[:message]
    ticket.subject.should eql truncate_subject(comment[:message], 100)
    ticket.requester_id.should eql user_id
    [ticket, comment_id]
  end
  
  def sample_dm_threads(thread_id, actor_id, msg_id)
    [
      {   
        "id" => thread_id, 
        "snippet"=> Faker::Lorem.sentence(1), 
        "updated_time"=> "#{Time.now.utc.iso8601}", 
        "message_count" => 1, 
        "messages" => 
          {
            "data" => [
              sample_dm_msg(actor_id, msg_id)
            ]
          }
      }
    ]
  end
  
  def sample_dm_msg(actor_id, msg_id)
    name = Faker::Name.name
    { 
      "id" =>  msg_id, 
      "created_time" => "#{Time.now.utc.iso8601}", 
      "from" => 
        {
          "name" => name,
          "email"=> Faker::Internet.email(name.split.last) , 
          "id"=> "#{actor_id}" 
        }, 
      "message"=> Faker::Lorem.sentence(4)
    } 
  end
  
  def generate_thread_id
    "t_id.#{(Time.now.utc.to_f * 1000).to_i}"
  end
  
  def generate_msg_id
    "m_mid.#{(Time.now.utc.to_f * 1000).to_i}:#{rand(36**15).to_s(36)}"
  end
  
end
