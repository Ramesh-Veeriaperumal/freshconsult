require_relative '../../api/unit_test_helper'

class MessageParserTest < ActionView::TestCase
  include ChannelIntegrations::Utils::MessageParser

  def test_allow_other_owner_events
    result = ignore_owner?('somerandomowner')
    assert_equal false, result
  end
end
