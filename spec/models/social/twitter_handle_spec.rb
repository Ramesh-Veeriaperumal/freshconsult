require 'spec_helper'
include GnipHelper
include Social::Twitter::Constants

describe Social::TwitterHandle do

  self.use_transactional_fixtures = false

  before(:all) do
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      Gnip::RuleClient.any_instance.stubs(:add).returns(add_response)
    end
    @handle = create_test_twitter_handle(@account)
    @default_stream = @handle.default_stream
    update_db(@default_stream) unless GNIP_ENABLED
    @dm_stream = @handle.dm_stream
    @rule = @default_stream.gnip_rule
  end

  before(:each) do
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([])
      Gnip::RuleClient.any_instance.stubs(:add).returns(add_response)
      Gnip::RuleClient.any_instance.stubs(:delete).returns(delete_response)
    end
    @handle.reload
  end

  it "should create a twitter stream of 'default' kind and 'dm' kind" do
    @default_stream.should_not be_nil
    @dm_stream.should_not be_nil
  end

  it "should create a gnip rule for the default stream (with gnip subsription enabled)" do
    #Check rule in gnip
    if GNIP_ENABLED
      mrule = gnip_rule(@rule)
      mrule.should_not be_nil

      #check for matching rule tag
      tag_delimiter = Gnip::Constants::DELIMITER[:tags]
      tags = mrule.tag.split(tag_delimiter)
      tags.should include(@rule[:tag])
    end
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


  it "should delete the default gnip rule and the default streams if account is suspended" do
    current_state = @handle.account.subscription.state
    handle_id = @handle.id

    if current_state != "suspended"
      @handle.account.subscription.update_attributes(:state => "suspended")
      if GNIP_ENABLED
        mrule = gnip_rule(@rule)
        tag_delimiter = Gnip::Constants::DELIMITER[:tags]
        if !mrule.nil?
          tags = mrule.tag.split(tag_delimiter)
          tags.should_not include(@rule[:tag])
        end
      end

      #stream should be deleted
      stream = Social::TwitterStream.find_by_social_id handle_id
      stream.should be_nil
    end
  end


  it "should create the default and dm stream and add a gnip rule if state is changed from suspended to active " do
    current_state = @handle.account.subscription.state
    if current_state == "suspended"
      Gnip::RuleClient.any_instance.stubs(:add).returns(add_response) unless GNIP_ENABLED
      @handle.account.subscription.update_attributes(:state => "trial")
      stream = @handle.default_stream
      update_db(@default_stream) unless GNIP_ENABLED
      stream.should_not be_nil
      
      dm_stream = @handle.dm_stream
      dm_stream.should_not be_nil

      rule = stream.gnip_rule
      
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


  it "should add custom streams if its search_keys are updated" do
    new_keys = ["freshservice", "freshchat"]
    @handle.update_attributes(:search_keys => new_keys)
    @handle.reload
    custom_stream_keys = @handle.twitter_streams.map{|stream| stream.name if stream.data[:kind] == STREAM_TYPE[:custom]}.compact
    @handle.search_keys.delete(@handle.formatted_handle)
    custom_stream_keys.should == @handle.search_keys
    
  end


  it "should destroy the gnip rule default_stream dm_stream and associated rules with the default 
        stream and the dm stream on twitter handle destroy and set social id to nil for associated custom streams" do
    handle_id = @handle.id
    #Destroy the handle
    @handle.destroy

    #stream should be deleted
    stream = Social::TwitterStream.find_by_social_id handle_id
    stream.should be_nil

    if GNIP_ENABLED
      #Check gnip to make sure the rule is deleted
      mrule = gnip_rule(@rule)
      tag_delimiter = Gnip::Constants::DELIMITER[:tags]
      if !mrule.nil?
        #check for matching rule tag
        tags = mrule.tag.split(tag_delimiter)
        tags.should_not include(@rule[:rule_tag])
      end
    end

    #Ensure the handle has been deleted
    handle = Social::TwitterHandle.find_by_id(handle_id)
    handle.should be_nil
    custom_streams = Social::TwitterStream.find(:all).map{|stream| stream.social_id if stream.data[:kind] == STREAM_TYPE[:custom]}.compact
    custom_streams.should_not include(handle_id)    
  end
  

  after(:all) do
    #Destroy the twitter handle
    GnipRule::Client.any_instance.stubs(:list).returns([]) unless GNIP_ENABLED
    Gnip::RuleClient.any_instance.stubs(:delete).returns(delete_response) unless GNIP_ENABLED
    #@handle.destroy
    # Social::Stream.destroy_all
    # Social::Tweet.destroy_all
    Resque.inline = false
  end

end

