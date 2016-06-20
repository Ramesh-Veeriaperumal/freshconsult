require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module FacebookHelper
  
  def create_test_facebook_page(account = nil, populate_streams = false)
    account = create_test_account if account.nil?
    fb_page = FactoryGirl.build(:facebook_pages, :account_id => account.id)
    fb_page.save
    if populate_streams
      fb_page.account.make_current
      fb_page.build_default_streams
    end
    fb_page
  end
  
  def sample_facebook_pages(page_id, name)
    [
      {
        "category" => Faker::Name.name, 
        "name" => "#{name}",
        "access_token" => "#{get_social_id}",
        "perms" => ["ADMINISTER", "EDIT_PROFILE", "CREATE_CONTENT", "MODERATE_CONTENT", "CREATE_ADS", "BASIC_ADMIN"], 
        "id" => "#{page_id}"
      }
    ]
  end
  
  def sample_enable_page_params(page_id)
    pages = {
      "profile_id" => "100005115430108",
      "access_token" => "sdsdfdsf",
      "page_id" => "#{page_id}",
      "page_name" => "TEST",
      "page_token" => "sdfsdf",
      "page_img_url" => "https => //m-static.ak.fbcdn.net/rsrc.php/v2/yv/r/zxpGQEKWB25.png",
      "page_link" => "https => //www.facebook.com/pages/TEST/1463329723913690",
      "fetch_since" => 0,
      "reauth_required" => false,
      "last_error" => nil
    }
    pages = pages.to_json
    {
      "enable" => 
        {
          "pages" =>
          [
            pages
          ]
        }
    }
  end
  
  def sample_page_info(page_id, name)
    {
      "id" => "#{page_id}", 
      "about" => Faker::Lorem.sentence(3), 
      "can_post" => true, 
      "category" => "Community", 
      "checkins" => 0, 
      "has_added_app" => true, 
      "is_community_page" => false, 
      "is_published" => true, 
      "new_like_count" => 0, 
      "likes" => 0, 
      "link" => Faker::Internet.url, 
      "name" => "#{name}", 
      "offer_eligible" => false, 
      "parking" => {
        "lot"=>0, 
        "street"=>0, 
        "valet"=>0
        }, 
      "promotion_eligible" => false, 
      "promotion_ineligible_reason" => "BOOSTED_POST__NOT_ENOUGH_PAGE_LIKES", 
      "talking_about_count" => 0, 
      "unread_message_count" => 0, 
      "unread_notif_count" => 0, 
      "unseen_message_count" => 0, 
      "were_here_count" => 0
    }
  end
  
  def sample_facebook_feed(sender_id, feed_id, comment_id = nil)
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
    
    fb_feed
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
  
  def get_dynamo_feed(table, range_key, attributes_to_get)
    schema            = TABLES["#{table}"][:schema]
    table_name        = Social::DynamoHelper.select_table("#{table}", Time.now.utc)
    hash              = "#{@account.id}_#{@default_stream.id}"
    Social::DynamoHelper.get_item(table_name, hash, "#{range_key}", schema, attributes_to_get)
  end
  
  def get_social_id
    (Time.now.utc.to_f*1000000).to_i
  end
  
end
