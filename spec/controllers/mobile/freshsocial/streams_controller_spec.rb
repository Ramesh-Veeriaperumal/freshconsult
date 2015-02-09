require 'spec_helper'

include GnipHelper
include DynamoHelper
include Social::Twitter::Constants
include Social::Dynamo::Twitter
include Social::Util

describe Social::StreamsController do
  self.use_transactional_fixtures = false

  before(:all) do
    #handles
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([])
      GnipRule::Client.any_instance.stubs(:add).returns(add_response)
    end
    @first_handle = create_test_twitter_handle(@account)
    @first_default_stream = @first_handle.default_stream
    @first_data = @first_default_stream.data
    update_db(@first_default_stream) unless GNIP_ENABLED
    @first_rule = {:rule_value => @first_data[:rule_value], :rule_tag => @first_data[:rule_tag]}

    @sec_handle = create_test_twitter_handle(@account)
    @sec_default_stream = @sec_handle.default_stream
    @sec_data = @sec_default_stream.data
    update_db(@sec_default_stream) unless GNIP_ENABLED
    @sec_rule = {:rule_value => @sec_data[:rule_value], :rule_tag => @sec_data[:rule_tag]}
    Resque.inline = false
    AgentGroup.destroy_all
  end

  before(:each) do
    api_login
  end

  describe "#stream_feeds" do
    it "should fetch all the streams and also meta_data" do
      all_streams = @agent.visible_social_streams
      default_streams = all_streams.select { |stream| stream.default_stream? }
      custom_streams  = all_streams.select { |stream| stream.custom_stream? }
      get :stream_feeds, { :format => "json", :send_meta_data => "true" }
      json_response.should include("streams","custom_streams","thumb_avatar_urls","meta_data","sorted_feeds","first_feed_ids","last_feed_ids")
      json_response["streams"].each do |stream|
        stream.should include("twitter_stream")
        stream["twitter_stream"].should include("account_id","data","description","excludes","filter","id","includes","name","social_id")
      end
    end

    it "should fetch only the streams" do
      all_streams = @agent.visible_social_streams
      default_streams = all_streams.select { |stream| stream.default_stream? }
      custom_streams  = all_streams.select { |stream| stream.custom_stream? }
      get :stream_feeds, {
                        :social_streams =>
                          {
                            :stream_id => "#{@first_default_stream.id}",
                            :first_feed_id => "0,0",
                            :last_feed_id => "0,0"
                          },
                          "format" => "json"
                      }
      json_response.should include("sorted_feeds", "first_feed_ids", "last_feed_ids", "reply_privilege")
    end

    it "should get the old tweets" do
      get :show_old, {
                        :social_streams =>
                          {
                            :stream_id => "#{@first_default_stream.id}",
                            :first_feed_id => "0,0",
                            :last_feed_id => "0,0"
                          },
                          "format" => "json"
                      }

      json_response.should include("sorted_feeds", "first_feed_ids", "last_feed_ids", "reply_privilege")
    end

    it "should get the new tweets" do
      get :fetch_new, {
                            :social_streams =>
                                {
                                  :stream_id => "#{@first_default_stream.id}",
                                  :first_feed_id => "0,0",
                                  :last_feed_id => "0,0"
                                },
                                "format" => "json"
                          }

      json_response.should include("sorted_feeds", "first_feed_ids", "last_feed_ids", "reply_privilege")
    end
  end
  
  after(:all) do
    #Destroy the twitter handle
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([])
      GnipRule::Client.any_instance.stubs(:delete).returns(delete_response)
    end
    Resque.inline = false
  end
end
