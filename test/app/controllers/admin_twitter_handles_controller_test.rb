require_relative '../../api/test_helper'
require_relative '../../core/helpers/controller_test_helper'
['twitter_helper.rb', 'social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class Admin::Social::TwitterHandlesControllerTest < ActionController::TestCase
  include TwitterHelper
  include ControllerTestHelper
  include SocialTicketsCreationHelper

  def create_sample_handle
    handle = FactoryGirl.build(:seed_twitter_handle)
    handle.account_id = @account.id
    handle.state = Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:activation_required]
    handle.save
    handle
  end

  def make_mention_stream_inactive(handle)
    handle.twitter_streams.each do |stream|
      next if stream.data[:kind] != Social::Twitter::Constants::TWITTER_STREAM_TYPE[:default]

      stream.data[:gnip] = Social::Constants::GNIP_RULE_STATES_KEYS_BY_TOKEN[:none]
      stream.data[:gnip_rule_state] = nil
      stream.save
      return stream
    end
  end

  def test_activate_handle
    login_admin
    AccountAdditionalSettings.any_instance.stubs(:additional_settings).returns(clone: { account_id: 1 })
    # create handle in the activation required state
    handle = create_sample_handle
    stream = make_mention_stream_inactive(handle)
    put :activate, id: handle.id
    assert_response 302
    handle.reload
    stream.reload
    assert_equal Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:active], handle.state
    assert_equal true, stream.data[:gnip]
    assert_equal Social::Constants::GNIP_RULE_STATES_KEYS_BY_TOKEN[:none], stream.data[:gnip_rule_state]
  ensure
    AccountAdditionalSettings.any_instance.unstub(:additional_settings)
  end

  def test_activate_handle_failure
    login_admin
    # create handle in the activation required state
    handle = create_sample_handle
    stream = make_mention_stream_inactive(handle)
    Social::TwitterHandle.any_instance.stubs(:save).returns(false)
    put :activate, id: handle.id
    assert_response 302
    handle.reload
    stream.reload
    assert_equal Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:activation_required], handle.state
    assert_equal Social::Constants::GNIP_RULE_STATES_KEYS_BY_TOKEN[:none], stream.data[:gnip]
    assert_nil stream.data[:gnip_rule_state]
  ensure
    Social::TwitterHandle.any_instance.unstub(:save)
  end

  def test_activate_handle_stream_failure
    login_admin
    # create handle in the activation required state
    handle = create_sample_handle
    stream = make_mention_stream_inactive(handle)
    Social::TwitterStream.any_instance.stubs(:save).returns(false)
    put :activate, id: handle.id
    assert_response 302
    handle.reload
    stream.reload
    assert_equal Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:active], handle.state
    assert_equal Social::Constants::GNIP_RULE_STATES_KEYS_BY_TOKEN[:none], stream.data[:gnip]
    assert_nil stream.data[:gnip_rule_state]
  ensure
    Social::TwitterStream.any_instance.unstub(:save)
  end
end
