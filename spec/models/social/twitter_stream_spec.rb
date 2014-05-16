require 'spec_helper'
include GnipHelper
include Social::Twitter::Constants

describe Social::TwitterStream do

  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns(nil) 
      Gnip::RuleClient.any_instance.stubs(:add).returns(add_response) 
    end
    @handle = create_test_twitter_handle(@account, false)
    @stream = @handle.default_stream
    update_stream_rule(@stream) unless GNIP_ENABLED
  end

  before(:each) do
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns(nil)
      Gnip::RuleClient.any_instance.stubs(:add).returns(add_response) 
      Gnip::RuleClient.any_instance.stubs(:delete).returns(delete_response)
    end
    @handle.reload
  end

  # @ARV@ TODO Delete twitter handle, should set social_id to nil for custom streams

  it "should create a twitter stream of 'default' kind" do
    @stream.should_not be_nil
    @stream.data[:kind].should be_eql(Social::Twitter::Constants::STREAM_TYPE[:default])
  end
  
  
  it "should create twitter streams of 'custom' kind for search keys other than twitter_handle" do
    @streams = @handle.twitter_streams
    streams = @streams.map{|stream| stream.includes if stream.data[:kind] == STREAM_TYPE[:custom]}.flatten.compact
    streams.length.should equal(@handle.search_keys.length-1)
  end

  it "should create a gnip rule" do
    if GNIP_ENABLED
      #Check rule in gnip
      mrule = gnip_rule(@stream.gnip_rule)
      mrule.should_not be_nil

      #check for matching rule tag
      tag_delimiter = Gnip::Constants::DELIMITER[:tags]
      tags = mrule.tag.split(tag_delimiter)
      tags.should include(@stream.gnip_rule[:tag])
    end
  end

  it "should insert keywords into streams <includes>" do
    @streams = @handle.twitter_streams
    includes = @streams.map{|stream| stream.includes}.flatten
    includes.should have(5).items
    includes.should include("@freshdesk", "freshdesk", "@TestingGnip", "from:TestingGnip", "TestingGnip")
  end

  it "should create a ticket rule with blank in the includes" do
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
  
  it "should add  new ticket rule if 'capture_mention_as_dm' is seleted" do
    @handle.update_attributes(:capture_dm_as_ticket => true)
    @dm_stream = @handle.dm_stream
    @dm_stream.ticket_rules.first.should_not be_nil
  end

  it "should ticket rule if 'capture_mention_as_dm' is deseleted" do
    @handle.update_attributes(:capture_dm_as_ticket => false)
    @dm_stream = @handle.dm_stream
    @dm_stream.ticket_rules.first.should be_nil
  end


  # it "should delete the gnip rule if account is suspended" do
  #   current_state = @handle.account.subscription.state
  #   stream_id = @stream.id
  #   rule = @stream.gnip_rule
  #   if current_state != "suspended"
  #     @handle.account.subscription.update_attributes(:state => "suspended")
  #     if GNIP_ENABLED
  #       mrule = gnip_rule(rule)
  #       tag_delimiter = Gnip::Constants::DELIMITER[:tags]
  #       if !mrule.nil?
  #         tags = mrule.tag.split(tag_delimiter)
  #         tags.should_not include(rule[:tag])
  #       end
  #     end
  #     stream = Social::Stream.find_by_id(stream_id)
  #     stream.should be_nil
  #   end
  # end

  it "should create the rule if state is changed from suspended to active " do
    current_state = @handle.account.subscription.state
    if current_state == "suspended"
      @handle.account.subscription.update_attributes(:state => "trial")

      if GNIP_ENABLED
        rule = @handle.gnip_rule
        mrule = gnip_rule(rule)
        mrule.should_not be_nil

        mrule.value.should eql rule[:value]
        tag_delimiter = Gnip::Constants::DELIMITER[:tags]
        tags = mrule.tag.split(tag_delimiter)
        tags.should include(rule[:tag])
      end
    end
  end

  it "should delete the gnip rule on destroy" do
    handle_id = @handle.id
    #stream_id = @stream.id
    rule = @handle.gnip_rule

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
    handle.should be_nil

    # stream = Social::Stream.find_by_id(stream_id)
    # stream.should be_nil
  end
  
  after(:all) do
    Resque.inline = false
  end

end

