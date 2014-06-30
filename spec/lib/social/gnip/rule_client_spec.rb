require 'spec_helper'

include GnipHelper
include Gnip::Constants
include Social::Twitter::Constants

describe Gnip::RuleClient do

  self.use_transactional_fixtures = false

 
  it "should subscribe to gnip on calling add" do
    if GNIP_ENABLED
      rule = {
                :value => "(@TestingGnip OR from:TestingGnip)",
                :tag => "S0_0"
            }
      rule_client = Gnip::RuleClient.new("Twitter", STREAM[:production], rule)
      rule_client.add
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
    if GNIP_ENABLED
      rule_new = {
                :value => "(@TestingGnip OR from:TestingGnip -rt)",
                :tag => "S0_0"
            }
      rule_client = Gnip::RuleClient.new("Twitter", STREAM[:production], rule_new)
      rule_client.add
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
    if GNIP_ENABLED
      rule = {
                :value => "(@TestingGnip OR from:TestingGnip -rt)",
                :tag => "S0_0"
            }
      rule_client = Gnip::RuleClient.new("Twitter", STREAM[:production], rule)
      rule_client.delete
      #Check rule in gnip
      mrule = gnip_rule(rule)
      mrule.should be_nil
    end
  end
  
end
