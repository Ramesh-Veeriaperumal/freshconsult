require_relative '../unit_test_helper'

class BotValidationTest < ActionView::TestCase
  def test_email_channel_invalid_data_type
    Account.stubs(:current).returns(Account.new)
    params = {
      'email_channel' => 1234
    } 
    bot_validation = BotValidation.new(params, Bot.new) 
    refute bot_validation.valid?
    errors = bot_validation.errors.full_messages
    assert errors.include?("Email channel datatype_mismatch")
    Account.unstub(:current)
  end

  def test_email_channel_with_empty
    Account.stubs(:current).returns(Account.new)
    params = {
      'email_channel' => ''
    }
    bot_validation = BotValidation.new(params, Bot.new)
    refute bot_validation.valid?
    errors = bot_validation.errors.full_messages
    assert errors.include?("Email channel datatype_mismatch")
    Account.unstub(:current)
  end

  def test_valid_notification
    Account.stubs(:current).returns(Account.new)
    params = {
      'email_channel' => true
    }
    bot_validation = BotValidation.new(params, Bot.new)
    assert bot_validation.valid?
    Account.unstub(:current)
  end
end