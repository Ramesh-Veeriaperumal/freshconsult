require 'spec_helper'

include GnipHelper
include Gnip::Constants
include Social::Twitter::Constants


RSpec.describe Gnip::RuleClient do

  self.use_transactional_fixtures = false

  before(:each) do
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:add).returns(add_response)
      GnipRule::Client.any_instance.stubs(:delete).returns(delete_response)
    end
  end
 
  it "should subscribe to gnip on calling add" do
    GnipRule::Client.any_instance.stubs(:list).returns([]) unless GNIP_ENABLED
    rule = {
              :value => "(@TestingGnip OR from:TestingGnip)",
              :tag => "S0_0"
          }
    rule_client = Gnip::RuleClient.new("Twitter", STREAM[:production], rule)
    rule_client.add
    
    if GNIP_ENABLED
      #Check rule in gnip
      mrule = gnip_rule(rule)
      mrule.should_not be_nil

      #check for matching rule tag
      tag_delimiter = Gnip::Constants::DELIMITER[:tags]
      tags = mrule.tag.split(tag_delimiter)
      tags.should include(rule[:tag])
    end
  end
  
  it "should update a gnip rule on calling update" do
    rule_list = [GnipRule::Rule.new("(@TestingGnip OR from:TestingGnip -rt)","S0_0")]
    GnipRule::Client.any_instance.stubs(:list).returns(rule_list) unless GNIP_ENABLED
    rule_new = {
              :value => "(@TestingGnip OR from:TestingGnip -rt)",
              :tag => "S0_1"
          }
    rule_client = Gnip::RuleClient.new("Twitter", STREAM[:production], rule_new)
    rule_client.add
    
    if GNIP_ENABLED
      #Check rule in gnip
      mrule = gnip_rule(rule_new)
      mrule.should_not be_nil

      #check for matching rule tag
      tag_delimiter = Gnip::Constants::DELIMITER[:tags]
      tags = mrule.tag.split(tag_delimiter)
      tags.should include(rule_new[:tag])
    end
  end
  
  it "should unsubscribe from gnip on calling delete" do
    rule_list = [GnipRule::Rule.new("(@TestingGnip OR from:TestingGnip -rt)","S0_0")]
    GnipRule::Client.any_instance.stubs(:list).returns(rule_list) unless GNIP_ENABLED
    rule = {
              :value => "(@TestingGnip OR from:TestingGnip -rt)",
              :tag => "S0_0"
          }
    rule_client = Gnip::RuleClient.new("Twitter", STREAM[:production], rule)
    rule_client.delete
    
    if GNIP_ENABLED
      #Check rule in gnip
      mrule = gnip_rule(rule)
      mrule.should be_nil
    end
  end
  
end
