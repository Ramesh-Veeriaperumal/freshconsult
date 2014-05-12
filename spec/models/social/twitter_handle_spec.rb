require 'spec_helper'
include GnipHelper

describe Social::TwitterHandle do

  self.use_transactional_fixtures = false

  before(:all) do
    Resque.inline = true
    @account = create_test_account
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      Gnip::RuleClient.any_instance.stubs(:add).returns(add_response) 
    end
    @handle = create_test_twitter_handle(@account, true)
    update_handle_rule(@handle) unless GNIP_ENABLED
    @stream = @handle.default_stream
    @rule = @handle.gnip_rule
  end

  before(:each) do
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      Gnip::RuleClient.any_instance.stubs(:add).returns(add_response) 
      Gnip::RuleClient.any_instance.stubs(:delete).returns(delete_response) 
    end
    @handle.reload
  end

  it "should not create a twitter stream" do
    @stream.should be_nil
  end

  it "should create a gnip rule" do
    if GNIP_ENABLED
      #Check rule in gnip
      mrule = gnip_rule(@rule)
      mrule.should_not be_nil

      #check for matching rule tag
      tag_delimiter = Gnip::Constants::DELIMITER[:tags]
      tags = mrule.tag.split(tag_delimiter)
      tags.should include(@rule[:tag])
    end
  end

  it "should delete gnip rule if 'capture_mention_as_ticket' is deselected" do
    @handle.update_attributes(:capture_mention_as_ticket => false)

    if GNIP_ENABLED
      mrule = gnip_rule(@rule)
      tag_delimiter = Gnip::Constants::DELIMITER[:tags]
      if !mrule.nil?
        #check for matching rule tag
        tags = mrule.tag.split(tag_delimiter)
        tags.should_not include(@rule[:tag])
      end
    end
  end

  it "should not add a new stream if 'capture_mention_as_ticket' is seleted" do
    @handle.update_attributes(:capture_mention_as_ticket => true)
    @handle.reload

    #Stream should be nil
    @stream = @handle.default_stream
    @stream.should be_nil

    #Check rule in gnip
    if GNIP_ENABLED
      @rule = @handle.gnip_rule
      mrule = gnip_rule(@rule)
      mrule.should_not be_nil
      
      #check for matching rule tag
      tag_delimiter = Gnip::Constants::DELIMITER[:tags]
      tags = mrule.tag.split(tag_delimiter)
      tags.should include(@rule[:tag])
    end
  end

  it "should destroy the gnip rule on twitter handle destroy" do
    handle = create_test_twitter_handle(nil, true)
    rule = handle.gnip_rule

    handle_id = handle.id

    #Destroy the handle
    handle.reload
    handle.destroy

    #Check gnip to make sure the rule is deleted
    if GNIP_ENABLED
      mrule = gnip_rule(rule)
      tag_delimiter = Gnip::Constants::DELIMITER[:tags]
      if !mrule.nil?
        #check for matching rule tag
        tags = mrule.tag.split(tag_delimiter)
        tags.should_not include(rule[:rule_tag])
      end
    end

    #Ensure the handle has been deleted
    handle = Social::TwitterHandle.find_by_id(handle_id)
    handle.should be_nil
  end

  it "should delete the gnip rule if account is suspended" do
    current_state = @handle.account.subscription.state
    rule = @handle.gnip_rule
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
    end
  end

  it "should create the rule if state is changed from suspended to active " do
    current_state = @handle.account.subscription.state
    if current_state == "suspended"
      @handle.account.subscription.update_attributes(:state => "trial")
      rule = @handle.gnip_rule
      update_handle_rule(@handle) unless GNIP_ENABLED

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

  it "should delete the gnip rule on handle destroy" do
    handle_id = @handle.id

    #Destroy the handle
    @handle.destroy

    #Check gnip to make sure the rule is deleted
    mrule = gnip_rule(@rule)
    tag_delimiter = Gnip::Constants::DELIMITER[:tags]
    if !mrule.nil?
      #check for matching rule tag
      tags = mrule.tag.split(tag_delimiter)
      tags.should_not include(@rule[:rule_tag])
    end

    #Ensure the handle has been deleted
    handle = Social::TwitterHandle.find_by_id(handle_id)
    handle.should be_nil

    @handle = nil
  end

  after(:all) do
    Resque.inline = false
  end

end

