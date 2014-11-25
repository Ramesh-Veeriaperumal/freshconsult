require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module FacebookHelper
  
  def create_test_facebook_page(account = nil, populate_streams = false)
    account = create_test_account if account.nil?
    fb_page = Factory.build(:facebook_pages, :account_id => account.id)
    fb_page.save
    if populate_streams
      fb_page.account.make_current
      fb_page.build_default_streams
    end
    fb_page
  end
  
  def sample_realtime_feed(feed_id, post)
    realtime_feed = {
      "entry" => {
          "id" => "#{@fb_page.page_id}",
          "time" => Time.now.utc.to_i,
          "changes" => [{
              "field" => "feed", 
              "value" => { 
                    "item" => "#{post}", 
                    "verb" => "add", 
                    "post_id" => "#{feed_id}"
                  }
                }]
        }
    }
    realtime_feed.to_json
  end
  
  def sample_user_profile(user_id)
    {
      :id => "#{user_id}",
      :name => "Facebook User"
    }
  end
  
  def sample_realtime_comment_feed(feed_id, parent = false, parent_id = nil)
    realtime_feed = {
      "entry" => {
          "id" => "#{@fb_page.page_id}",
          "time" => Time.now.utc.to_i,
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
    
    if parent
      realtime_feed.merge!({
        "parent" => {
          "id" => "#{parent_id}"
        }
      })
    end    
    realtime_feed.to_json
  end
  
  def sample_fql_feed(feed_id, visitor_post = true)
    actor_id = visitor_post ? "#{get_social_id}" : "#{@fb_page.page_id}"
    fql_feed = {
      :post_id => "#{feed_id}",
      :actor_id => actor_id.to_i
    }
    sample_feeds = [fql_feed]
  end
  
  def sample_facebook_feed(visitor_post, feed_id, comments = false, reply_to_comments = false)
    actor_id = visitor_post ? "#{get_social_id}" : "#{@fb_page.page_id}"
    page_id = "#{feed_id.split('_').first}"
    post_id = "#{feed_id.split('_').second}"
    fb_feed = {
      "id" => "#{feed_id}", 
      "from" => {
        :category => "Community", 
        :name => "Helloworld", 
        :id => actor_id.to_i
      }, 
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
    feed_id = "#{@fb_page.page_id}_#{get_social_id}"
    realtime_feed = sample_realtime_feed(feed_id, "post")
    facebook_feed = sample_facebook_feed(true, feed_id)
    
    #stub the api call for koala
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
            
    Facebook::Core::Parser.new(realtime_feed).parse
    
    post = @account.facebook_posts.find_by_post_id(feed_id)
    post.should_not be_nil
    post.is_ticket?.should be_true
    
    ticket = post.postable
    [ticket, feed_id]
  end
  
  def sample_comment_and_ticket
    data = @default_stream.data.merge({:replies_enabled => true})
    @default_stream.update_attributes(:data => data)

    comment = sample_facebook_comment_feed(@fb_page.page_id, "#{(Time.now.utc.to_f*100000).to_i}", "Comment to post on facebook")
    comment_id = comment[:id]
    realtime_feed = sample_realtime_comment_feed(comment_id)
   
    
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(comment)
    
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
  
  
  def sample_fql_comment(post_id, comment_id)
   [ {
      :id     => "#{post_id.split('_')[1]}_#{comment_id}", 
      :fromid => "#{@fb_page.page_id}",
      :attachement => {
        :type => "post"
      },
      :text => "Commenting",
      :time => Time.now.utc.to_f*100000,
      :parent_id => "#{post_id}",
      :can_comment => false
    } ]
  end
  
end
