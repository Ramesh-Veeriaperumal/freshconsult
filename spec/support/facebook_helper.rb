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
  
end
