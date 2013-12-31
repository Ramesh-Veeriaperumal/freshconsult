require 'spec_helper'
include GnipHelper

describe Social::TwitterStream do

  self.use_transactional_fixtures = false

  before(:all) do
    Resque.inline = true
    @handle = create_test_twitter_handle()
    @stream = @handle.default_stream
  end

  before(:each) do
    @handle.reload
  end

  # @ARV@ TODO Delete twitter handle, should set social_id to nil for custom streams

  it "should create a twitter stream of 'default' kind" do
    @stream.should_not be_nil
    @stream.data[:kind].should be_eql(Social::Twitter::Constants::STREAM_TYPE[:default])
  end

  it "should create a gnip rule" do
    #Check rule in gnip
    mrule = gnip_rule(@stream.gnip_rule)
    mrule.should_not be_nil

    #check for matching rule tag
    tag_delimiter = Gnip::Constants::DELIMITER[:tags]
    tags = mrule.tag.split(tag_delimiter)
    tags.should include(@stream.gnip_rule[:tag])
  end

  it "should insert keywords into stream <includes>" do
    @stream.includes.should have(3).items #@freshdesk, freshdesk, @TestingGnip
    @stream.includes.should include("@freshdesk", "freshdesk", "@TestingGnip")
  end

  it "should create a ticket rule with only @mention in the includes" do
    verify_mention_rule(@handle.formatted_handle)
  end

  it "should delete ticket rules if 'capture_mention_as_ticket' is deselected" do
    @handle.update_attributes(:capture_mention_as_ticket => false)
    @stream.reload

    ticket_rules = @stream.ticket_rules
    ticket_rules.should be_empty
  end

  it "should add a new ticket rule if 'capture_mention_as_ticket' is seleted" do
    @handle.update_attributes(:capture_mention_as_ticket => true)
    @stream.reload
    verify_mention_rule(@handle.formatted_handle)
  end

  it "should update gnip rule when its search_keys are updated" do
    new_keys = ["freshdesk", "freshchat"]
    @handle.update_attributes(:search_keys => new_keys)

    @handle.reload
    @stream.reload

    @stream.includes.should have(3).items #@freshphone, freshchat, @TestingGnip
    @stream.includes.should include("freshdesk", "freshchat", "@TestingGnip")

    #Check rule in gnip
    mrule = gnip_rule(@stream.gnip_rule)
    mrule.should_not be_nil

    #check for matching rule tag
    tag_delimiter = Gnip::Constants::DELIMITER[:tags]
    tags = mrule.tag.split(tag_delimiter)
    tags.should include(@stream.gnip_rule[:tag])
  end

  it "should delete the gnip rule if account is suspended" do
    current_state = @handle.account.subscription.state
    stream_id = @stream.id
    rule = @stream.gnip_rule
    if current_state != "suspended"
      @handle.account.subscription.update_attributes(:state => "suspended")
      mrule = gnip_rule(rule)
      tag_delimiter = Gnip::Constants::DELIMITER[:tags]
      if !mrule.nil?
        tags = mrule.tag.split(tag_delimiter)
        tags.should_not include(rule[:tag])
      end

      stream = Social::Stream.find_by_id(stream_id)
      stream.should be_nil
    end
  end

  it "should create the rule if state is changed from suspended to active " do
    current_state = @handle.account.subscription.state
    if current_state == "suspended"
      @handle.account.subscription.update_attributes(:state => "trial")
      rule = @handle.gnip_rule

      mrule = gnip_rule(rule)
      mrule.should_not be_nil

      mrule.value.should eql rule[:value]
      tag_delimiter = Gnip::Constants::DELIMITER[:tags]
      tags = mrule.tag.split(tag_delimiter)
      tags.should include(rule[:tag])
    end
  end

  it "should delete the gnip rule on destroy" do
    handle_id = @handle.id
    #stream_id = @stream.id
    rule = @handle.gnip_rule

    #Destroy the handle
    @handle.destroy

    #Check rule in gnip
    mrule = gnip_rule(rule)
    tag_delimiter = Gnip::Constants::DELIMITER[:tags]
    if !mrule.nil?
      #check for matching rule tag
      tags = mrule.tag.split(tag_delimiter)
      tags.should_not include(rule[:tag])
    end

    #Ensure the handle and stream have been deleted
    handle = Social::TwitterHandle.find_by_id(handle_id)
    handle.should be_nil

    # stream = Social::Stream.find_by_id(stream_id)
    # stream.should be_nil
  end

  after(:all) do
    Resque.inline = false
  end

end

