require_relative '../../api/unit_test_helper'

class MessageParserTest < ActionView::TestCase
  include ChannelIntegrations::Utils::MessageParser

  def test_ignore_facebook_owner_events
    result = ignore_owner?('facebook')
    assert_equal true, result
  end

  def test_allow_other_owner_events
    result = ignore_owner?('somerandomowner')
    assert_equal false, result
  end

  def test_allowed_twitter_payload
    return_value = valid_twitter_update?(command_name: 'update_twitter_message', context: { tweet_type: 'dm' })
    assert_equal true, return_value
  end

  def test_mismatch_command_twitter_payload
    return_value = valid_twitter_update?(command_name: 'random_command', context: { tweet_type: 'dm' })
    assert_equal true, return_value
  end

  def test_disallowed_twitter_payload
    return_value = valid_twitter_update?(command_name: 'update_twitter_message', context: { tweet_type: 'mention' })
    assert_equal false, return_value
  end
end
