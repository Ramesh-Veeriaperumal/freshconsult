require_relative '../../unit_test_helper'
require Rails.root.join('test', 'api', 'helpers', 'email_settings_test_helper.rb')
class Email::SettingsValidationTest < ActionView::TestCase
  include EmailSettingsTestHelper

  def test_successful_update
    config = Email::SettingsValidation.new(all_features_params)
    assert config.valid?(:update)
  end

  def test_update_allow_agent_to_initiate_conversation_with_invalid_value
    params = { 'allow_agent_to_initiate_conversation': 'invalid_value' }
    config = Email::SettingsValidation.new(params)
    refute config.valid?(:update)
    errors = config.errors.full_messages
    assert errors.include?('Allow agent to initiate conversation datatype_mismatch')
  end

  def test_update_personalized_email_replies_with_invalid_value
    params = { 'personalized_email_replies': 'invalid_value' }
    config = Email::SettingsValidation.new(params)
    refute config.valid?(:update)
    errors = config.errors.full_messages
    assert errors.include?('Personalized email replies datatype_mismatch')
  end

  def test_update_create_requester_using_reply_to_with_invalid_value
    params = { 'create_requester_using_reply_to': 'invalid_value' }
    config = Email::SettingsValidation.new(params)
    refute config.valid?(:update)
    errors = config.errors.full_messages
    assert errors.include?('Create requester using reply to datatype_mismatch')
  end

  def test_update_original_sender_as_requester_for_forward_with_invalid_value
    params = { 'original_sender_as_requester_for_forward': 'invalid_value' }
    config = Email::SettingsValidation.new(params)
    refute config.valid?(:update)
    errors = config.errors.full_messages
    assert errors.include?('Original sender as requester for forward datatype_mismatch')
  end

  def test_skip_ticket_threading_with_invalid_value
    params = { 'skip_ticket_threading': 'invalid_value' }
    config = Email::SettingsValidation.new(params)
    refute config.valid?(:update)
    errors = config.errors.full_messages
    assert errors.include?('Skip ticket threading datatype_mismatch')
  end

  def test_allow_wildcard_ticket_create_with_invalid_value
    params = { 'allow_wildcard_ticket_create': 'invalid_value' }
    config = Email::SettingsValidation.new(params)
    refute config.valid?(:update)
    errors = config.errors.full_messages
    assert errors.include?('Allow wildcard ticket create datatype_mismatch')
  end

  def test_auto_response_detector_toggle_with_invalid_value
    params = { 'auto_response_detector_toggle': 'invalid_value' }
    config = Email::SettingsValidation.new(params)
    refute config.valid?(:update)
    errors = config.errors.full_messages
    assert errors.include?('Auto response detector toggle datatype_mismatch')
  end
end
