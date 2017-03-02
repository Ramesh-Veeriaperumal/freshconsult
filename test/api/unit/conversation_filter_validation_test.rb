require_relative '../unit_test_helper'

class ConversationFilterValidationTest < ActionView::TestCase
  def test_valid
    conversation_filter = ConversationFilterValidation.new(include: 'requester')
    result = conversation_filter.valid?(:ticket_conversations)
    assert result
  end

  def test_nil_value
    conversation_filter = ConversationFilterValidation.new(include: nil)
    refute conversation_filter.valid?(:ticket_conversations)
    error = conversation_filter.errors.full_messages
    assert error.include?('Include datatype_mismatch')
    assert_equal({ include: {
      expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null'
    }}, conversation_filter.error_options)
  end
end
