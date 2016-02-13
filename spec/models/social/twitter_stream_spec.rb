require 'spec_helper'
include Social::Twitter::Constants
RSpec.configure do |c|
  c.include GnipHelper
end

RSpec.describe Social::TwitterStream do

  self.use_transactional_fixtures = false

  before(:all) do
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:add).returns(add_response)
    end
    Resque.inline = true
    @handle = create_test_twitter_handle(@account)
    @default_stream = @handle.default_stream
    update_db(@default_stream) unless GNIP_ENABLED
    @dm_stream = @handle.dm_stream
    @custom_stream = create_test_custom_twitter_stream(@handle)
    @rule = @default_stream.gnip_rule
  end

  before(:each) do
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:add).returns(add_response)
      GnipRule::Client.any_instance.stubs(:delete).returns(delete_response)
    end
    @handle.reload
  end

  #@ARV@ TODO Delete twitter handle, should set social_id to nil for custom streams
  it "should create a twitter stream of 'default' kind and 'dm' kind on creating a handle" do
    @default_stream.should_not be_nil
    @dm_stream.should_not be_nil
  end

  it "should create a gnip rule for the default stream" do
    if GNIP_ENABLED
      #Check rule in gnip
      mrule = gnip_rule(@default_stream.gnip_rule)
      mrule.should_not be_nil

      #check for matching rule tag
      tag_delimiter = Gnip::Constants::DELIMITER[:tags]
      tags = mrule.tag.split(tag_delimiter)
      tags.should include(@default_stream.gnip_rule[:tag])
    end
  end
  
  it "should not create a gnip rule if gnip_subscription is false" do
    #Check rule in gnip
    mrule = gnip_rule(@custom_stream.gnip_rule)
    mrule.should be_nil
  end

  it "should create ticket rule for the dm stream if 'capture_dm_as_ticket' is selected " do
    @handle.update_attributes(:capture_dm_as_ticket => true)
    @handle.update_ticket_rules
    verify_mention_rule(@dm_stream)
  end

  it "should delete ticket rule for dm_stream if 'capture_dm_as_ticket' is deselected" do
    @handle.update_attributes(:capture_dm_as_ticket => false)
    @handle.update_ticket_rules
    ticket_rules = @dm_stream.ticket_rules
    ticket_rules.should be_empty
  end

  it "should delete the gnip rule for default stream if account is suspended" do
    Resque.inline = true
    @handle.account.subscription.update_attributes(:state => "trial") 
    @handle.reload
    
    current_state = @handle.account.subscription.state
    stream_id = @default_stream.id
    rule = @default_stream.gnip_rule
    if current_state != "suspended"
      @handle.account.subscription.update_attributes(:state => "suspended")
      if GNIP_ENABLED
        mrule = gnip_rule(rule)
        tag_delimiter = Gnip::Constants::DELIMITER[:tags]
        if !mrule.nil?
          tags = mrule.tag.split(tag_delimiter)
          tags.should_not include(rule[:tag])
        end
      end
      stream = Social::Stream.find_by_id(stream_id)
      stream.should be_nil
    end
    Resque.inline = false
  end
  
  it "should create a gnip rule for default stream if state is changed from suspended to active " do
    current_state = @handle.account.subscription.state
    if current_state == "suspended"
      @handle.account.subscription.update_attributes(:state => "trial")
      update_db(@handle.default_stream) unless GNIP_ENABLED
      rule = @handle.default_stream.gnip_rule
      
      if GNIP_ENABLED
        mrule = gnip_rule(rule)
        mrule.should_not be_nil

        mrule.value.should eql rule[:value]
        tag_delimiter = Gnip::Constants::DELIMITER[:tags]
        tags = mrule.tag.split(tag_delimiter)
        tags.should include(rule[:tag])
      end
    end
  end
  
  
  it "should change the rule value of custom streams on update of the search data" do
    @custom_stream.update_attributes(:excludes => ['Zendesk'])
    @custom_stream.data[:rule_vale].should == @custom_stream.gnip_rule[:rule_value]
  end
  
  
  it "should delete the gnip rule for default stream on destroy and set the social id of associated custom streams to nil" do
    Resque.inline = true
    handle_id = @handle.id
    rule = @rule

    #Destroy the handle
    @handle.destroy
    
    if GNIP_ENABLED
      #Check rule in gnip
      mrule = gnip_rule(rule)
      tag_delimiter = Gnip::Constants::DELIMITER[:tags]
      if !mrule.nil?
        #check for matching rule tag
        tags = mrule.tag.split(tag_delimiter)
        tags.should_not include(rule[:tag])
      end
    end
    #Ensure the handle and stream have been deleted
    handle = Social::TwitterHandle.find_by_id(handle_id)
    custom_streams = Social::TwitterStream.find(:all).map{|stream| stream.social_id if stream.data[:kind] == TWITTER_STREAM_TYPE[:custom]}.compact
    custom_streams.should_not include(handle_id)    
    handle.should be_nil
    Resque.inline = false
  end
  
  after(:all) do
    #Destroy the twitter handle
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:delete).returns(delete_response)
    end
    
    Social::TwitterHandle.destroy_all
    Social::Stream.destroy_all
    # Social::Tweet.destroy_all
    Resque.inline = false
  end

end
