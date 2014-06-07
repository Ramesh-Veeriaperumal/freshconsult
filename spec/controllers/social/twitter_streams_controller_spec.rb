require File.expand_path("#{File.dirname(__FILE__)}/../../spec_helper")

include GnipHelper
include DynamoHelper
include Social::Twitter::Constants
include Social::Dynamo::Twitter
include Social::Util

describe Admin::Social::TwitterStreamsController do
  
  setup :activate_authlogic
  
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      Gnip::RuleClient.any_instance.stubs(:add).returns(add_response)
    end
    @handle = create_test_twitter_handle(@account)
    @default_stream = @handle.default_stream
    @custom_stream = create_test_custom_twitter_stream
    @data = @default_stream.data
    update_db(@default_stream) unless GNIP_ENABLED
    @rule = {:rule_value => @data[:rule_value], :rule_tag => @data[:rule_tag]}
    Resque.inline = false
    @user = add_test_agent(@account)
    @user.make_current
    @new_stream = nil
  end
  
  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    log_in(@user)
  end
  
  it "should create a new twitter stream of type custom and create it's helpdesk access" do
    stream_name = "#{Faker::Lorem.words(1)}"
    includes = Faker::Lorem.words(1)
    excludes = Faker::Lorem.words(1)
    post :create, {
                    :twitter_stream =>
                      {
                        :name => "#{stream_name}", 
                        :includes => includes, 
                        :excludes => excludes, 
                        :filter => "", 
                        :social_id => ""
                      }, 
                    :social_twitter_stream => 
                      {
                        :product_id => "Default product"
                      },
                      :visible_to => ["0"], 
                      :social_ticket_rule => 
                      [
                        {
                          :ticket_rule_id => "",
                          :deleted => "false",
                          :includes => "Ticket rule includes", 
                          :group_id => "...", 
                          }
                      ]
                    }
    new_stream  = Social::TwitterStream.find_by_name(stream_name)
    new_stream[:includes].should eql(includes)
    new_stream[:excludes].should eql(excludes)
    new_stream.custom_stream?.should be_true
    new_stream.ticket_rules.should_not be_nil
    ticket_rule = new_stream.ticket_rules.first
    new_stream.accessible.should_not be_nil
  end
  
  it "should update a stream create/delete ticket rules if the includes is not empty and remove rules of deleted" do    
    stream_name = "#{Faker::Lorem.words(1)}"
    includes = Faker::Lorem.words(1)
    excludes = Faker::Lorem.words(1)
    post :create, {
                    :twitter_stream =>
                      {
                        :name => "#{stream_name}", 
                        :includes => includes, 
                        :excludes => excludes, 
                        :filter => "", 
                        :social_id => ""
                      }, 
                      :social_twitter_stream => 
                        {
                          :product_id => "Default product"
                        },
                      :visible_to => ["0"], 
                      :social_ticket_rule => 
                      [
                        {
                          :ticket_rule_id => "",
                          :deleted => "false",
                          :includes => ["Ticket rule includes"], 
                          :group_id => "...", 
                          }
                      ]
                    }
    new_stream  = Social::TwitterStream.find_by_name(stream_name)
    ticket_rule = new_stream.ticket_rules.first
    
    stream_name = "#{Faker::Lorem.words(1)}"
    includes = Faker::Lorem.words(1)
    excludes = Faker::Lorem.words(1)
    put :update, {
                    :id => new_stream.id,
                    :social_twitter_stream => 
                      {
                        :product_id => "Default product"
                      },
                    :twitter_stream =>
                      {
                        :name => new_stream.name, 
                        :includes => new_stream[:includes], 
                        :excludes => new_stream[:excludes], 
                        :filter => "", 
                        :social_id => ""
                      }, 
                      :visible_to => ["0"], 
                      :social_ticket_rule => 
                      [
                        {
                          :ticket_rule_id => ticket_rule.id,
                          :deleted => "true",
                          :includes => ["Ticket rule includes"], 
                          :group_id => "...", 
                          },
                        {
                          :ticket_rule_id => "",
                          :deleted => "false",
                          :includes => "", 
                          :group_id => "...", 
                        },
                        {
                          :ticket_rule_id => "",
                          :deleted => "false",
                          :includes => ["New Ticket rule"], 
                          :group_id => "...", 
                        }
                      ]
                    }
                    
    new_stream.ticket_rules.count.should eql(1)
    new_stream.ticket_rules.first[:filter_data][:includes].should eql(["New Ticket rule"])
  end
    
  after(:all) do
    #Destroy the twitter handle
    Resque.inline = true
    GnipRule::Client.any_instance.stubs(:list).returns([]) unless GNIP_ENABLED
    Gnip::RuleClient.any_instance.stubs(:delete).returns(delete_response) unless GNIP_ENABLED
    @handle.destroy
    Social::Stream.destroy_all
    Social::Tweet.destroy_all
    Resque.inline = false
  end
  
end
