require_relative '../../unit_test_helper'
require Rails.root.join('test', 'api', 'helpers', 'email_settings_test_helper.rb')
class Email::SettingsValidationTest < ActionView::TestCase
  include EmailSettingsTestHelper

  def test_successful_update
    config = Email::SettingsValidation.new(all_features_params)
    assert config.valid?(:update)
  end

  def test_update_allow_agent_to_initiate_conversation_with_invalid_value
    params = all_features_params.except(:personalized_email_replies, :original_sender_as_requester_for_forward, :create_requester_using_reply_to)
    params[:allow_agent_to_initiate_conversation] = 'invalid_value'
    config = Email::SettingsValidation.new(params)
    refute config.valid?(:update)
    errors = config.errors.full_messages
    assert errors.include?('Allow agent to initiate conversation datatype_mismatch')
  end

  def test_update_personalized_email_replies_with_invalid_value
    params = all_features_params.except(:allow_agent_to_initiate_conversation, :original_sender_as_requester_for_forward, :create_requester_using_reply_to)
    params[:personalized_email_replies] = 'invalid_value'
    config = Email::SettingsValidation.new(params)
    refute config.valid?(:update)
    errors = config.errors.full_messages
    assert errors.include?('Personalized email replies datatype_mismatch')
  end

  def test_update_create_requester_using_reply_to_with_invalid_value
    params = all_features_params.except(:personalized_email_replies, :original_sender_as_requester_for_forward, :allow_agent_to_initiate_conversation)
    params[:create_requester_using_reply_to] = 'invalid_value'
    config = Email::SettingsValidation.new(params)
    refute config.valid?(:update)
    errors = config.errors.full_messages
    assert errors.include?('Create requester using reply to datatype_mismatch')
  end

  def test_update_original_sender_as_requester_for_forward_with_invalid_value
    params = all_features_params.except(:personalized_email_replies, :allow_agent_to_initiate_conversation, :create_requester_using_reply_to)
    params[:original_sender_as_requester_for_forward] = 'invalid_value'
    config = Email::SettingsValidation.new(params)
    refute config.valid?(:update)
    errors = config.errors.full_messages
    assert errors.include?('Original sender as requester for forward datatype_mismatch')
  end
end
