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
