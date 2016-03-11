require_relative '../unit_test_helper'

class ConversationValidationTest < ActionView::TestCase
  def test_numericality
    controller_params = { 'user_id' => 1,  body: Faker::Lorem.paragraph }
    item = nil
    conversation = ConversationValidation.new(controller_params, item)
    assert conversation.valid?(:create)
  end

  def test_body
    controller_params = { 'user_id' => 1 }
    item = nil
    conversation = ConversationValidation.new(controller_params, item)
    refute conversation.valid?(:create)

    assert conversation.errors.full_messages.include?('Body datatype_mismatch')
    refute conversation.errors.full_messages.include?('Body html datatype_mismatch')
    assert_equal({ body: {  expected_data_type: String, code: :missing_field }, user_id: {} }, conversation.error_options)

    controller_params = { 'user_id' => 1, body: '', body_html: '' }
    item = nil
    conversation = ConversationValidation.new(controller_params, item)
    refute conversation.valid?(:create)
    assert conversation.errors.full_messages.include?('Body blank')
    refute conversation.errors.full_messages.include?('Body html datatype_mismatch')

    controller_params = { 'user_id' => 1, body: true, body_html: true }
    item = nil
    conversation = ConversationValidation.new(controller_params, item)
    refute conversation.valid?(:create)
    assert conversation.errors.full_messages.include?('Body datatype_mismatch')
    assert conversation.errors.full_messages.include?('Body html datatype_mismatch')
  end

  def test_emails_validation_invalid
    controller_params = { 'notify_emails' => ['fggg@ddd.com,ss@fff.com'], 'cc_emails' => ['fggg@ddd.com,ss@fff.com'], 'bcc_emails' => ['fggg@ddd.com,ss@fff.com']  }
    item = nil
    conversation = ConversationValidation.new(controller_params, item)
    refute conversation.valid?
    errors = conversation.errors.full_messages
    assert errors.include?('Cc emails array_invalid_format')
    assert errors.include?('Bcc emails array_invalid_format')
    assert errors.include?('Notify emails array_invalid_format')
  end

  def test_attachment_multiple_errors
    Account.stubs(:current).returns(Account.first)
    String.any_instance.stubs(:size).returns(20_000_000)
    TicketsValidationHelper.stubs(:attachment_size).returns(100)
    controller_params = { 'user_id' => 1, attachments: ['file.png'],  body: Faker::Lorem.paragraph }
    item = nil
    conversation = ConversationValidation.new(controller_params, item)
    refute conversation.valid?
    errors = conversation.errors.full_messages
    assert errors.include?('Attachments array_datatype_mismatch')
    assert_equal({ body: {}, user_id: {}, attachments: { expected_data_type: 'valid file format' } }, conversation.error_options)
    assert errors.count == 1
    Account.unstub(:current)
    TicketsValidationHelper.unstub(:attachment_size)
  end

  def test_complex_fields_with_nil
    controller_params = { 'notify_emails' => nil, 'cc_emails' => nil, 'bcc_emails' => nil, attachments: nil  }
    item = nil
    conversation = ConversationValidation.new(controller_params, item)
    refute conversation.valid?
    errors = conversation.errors.full_messages
    assert errors.include?('Notify emails datatype_mismatch')
    assert errors.include?('Bcc emails datatype_mismatch')
    assert errors.include?('Cc emails datatype_mismatch')
    assert errors.include?('Attachments datatype_mismatch')
    Account.unstub(:current)
  end
end
