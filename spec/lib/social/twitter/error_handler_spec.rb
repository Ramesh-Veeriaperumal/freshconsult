require 'spec_helper'
include Social::Twitter::ErrorHandler

describe "Twitter Error Handler" do
  
  self.use_transactional_fixtures = false
  
  before(:all) do
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:add).returns(add_response)
    end
    @handle = create_test_twitter_handle(@account)
    Resque.inline = false
  end
  
  it "must raise tweet already posted exception " do
    error_msg, return_value = twt_sandbox(@handle) do
      raise Twitter::Error::AlreadyPosted
    end
    error_msg.should eql("#{I18n.t('social.streams.twitter.already_tweeted')}")
  end
  
  it "must raise tweet already retweeted exception " do
    error_msg, return_value = twt_sandbox(@handle) do
      raise Twitter::Error::AlreadyRetweeted
    end
    error_msg.should eql("#{I18n.t('social.streams.twitter.already_retweeted')}")
  end
  
  it " must raise ratelimit reached exception " do
    error_msg, return_value = twt_sandbox(@handle) do
      raise Twitter::Error::TooManyRequests
    end
    error_msg.should eql("#{I18n.t('social.streams.twitter.rate_limit_reached')}")
  end
  
  it "must raise forbidden error" do
    error_msg, return_value = twt_sandbox(@handle) do
      raise Twitter::Error::Forbidden
    end
    error_msg.should eql("#{I18n.t('social.streams.twitter.client_error')}")
  end
  
  it "must raise gateway timeout exception" do
    error_msg, return_value = twt_sandbox(@handle) do
      raise Twitter::Error::GatewayTimeout
    end
    error_msg.should eql("GatewayTimeout Error")
  end
  
  it "must raise twitter exception" do
    error_msg, return_value = twt_sandbox(@handle) do
      raise Twitter::Error
    end
    error_msg.should eql("#{I18n.t('social.streams.twitter.client_error')}")
  end
  
  it "must raise authentication error" do
    error_msg, return_value = twt_sandbox(@handle) do
      raise Twitter::Error::Unauthorized
    end
    error_msg.should eql("#{I18n.t('social.streams.twitter.handle_auth_error')}")
    @handle.reload
    @handle.reauth_required?.should be_true
    @handle.state.should eql(Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required])
  end
  
  it "must pass an handle that requires reauth to the block" do
    @handle.update_attributes(:state => Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required])
    @handle.reload
    error_msg, return_value = twt_sandbox(@handle) {}
    error_msg.should eql("#{I18n.t('social.streams.twitter.handle_auth_error')}")
  end
  
  after(:all) do
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([])
      GnipRule::Client.any_instance.stubs(:delete).returns(delete_response)
    end
    @handle.destroy
    Resque.inline = false
    twt_sandbox(@handle) {}
  end
end
