require_relative '../unit_test_helper'

class ConversationValidationTest < ActionView::TestCase

  def setup
    Account.stubs(:current).returns(Account.first)
  end

  def teardown
    Account.unstub(:current)
  end

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
    assert_equal({ body: {  expected_data_type: String, code: :missing_field }, user_id: {} }, conversation.error_options)

    controller_params = { 'user_id' => 1, body: '' }
    item = nil
    conversation = ConversationValidation.new(controller_params, item)
    refute conversation.valid?(:create)
    assert conversation.errors.full_messages.include?('Body blank')

    controller_params = { 'user_id' => 1 }
    item = Helpdesk::Note.new
    item.note_body.body = ''
    item.note_body.body_html = 'test'
    conversation = ConversationValidation.new(controller_params, item)
    assert conversation.valid?(:update)

    controller_params = { 'user_id' => 1, body: true }
    item = nil
    conversation = ConversationValidation.new(controller_params, item)
    refute conversation.valid?(:create)
    assert conversation.errors.full_messages.include?('Body datatype_mismatch')

    controller_params = { 'agent_id' => 1, body: 'Test' }
    item = nil
    conversation = ConversationValidation.new(controller_params, item, false)
    refute conversation.valid?(:forward)
    assert conversation.errors.full_messages.include?('To emails missing_field')

    controller_params = { user_id: 1, attachment_ids: [], body: '' }
    item = Helpdesk::Note.new
    conversation = ConversationValidation.new(controller_params, item)
    refute conversation.valid?(:reply)
    assert conversation.errors.full_messages.include?('Body blank')

    controller_params = { user_id: 1, attachment_ids: [1], body: '' }
    item = Helpdesk::Note.new
    conversation = ConversationValidation.new(controller_params, item)
    assert conversation.valid?(:reply)

    controller_params = { user_id: 1, attachment_ids: [1], body: '' }
    item = Helpdesk::Note.new
    conversation = ConversationValidation.new(controller_params, item)
    assert conversation.valid?(:create)

    controller_params = { user_id: 1, attachment_ids: [], body: 'Test' }
    item = Helpdesk::Note.new
    conversation = ConversationValidation.new(controller_params, item)
    assert conversation.valid?(:reply)
  end

  def test_emails_validation_invalid
    controller_params = { 'notify_emails' => ['fggg@ddd.com,ss@fff.com'], 'to_emails' => ['fggg@ddd.com,ss@fff.com'],
                            'cc_emails' => ['fggg@ddd.com,ss@fff.com'], 'bcc_emails' => ['fggg@ddd.com,ss@fff.com'],
                            'from_email' => 'fggg@ddd.com,ss@fff.com'  }
    item = nil
    conversation = ConversationValidation.new(controller_params, item)
    refute conversation.valid?
    errors = conversation.errors.full_messages
    assert errors.include?('Cc emails array_invalid_format')
    assert errors.include?('To emails array_invalid_format')
    assert errors.include?('Bcc emails array_invalid_format')
    assert errors.include?('Notify emails array_invalid_format')
    assert errors.include?('From email invalid_format')
  end

  def test_emails_validation_invalid_new_regex_enabled
    Account.stubs(:current).returns(Account.first || create_test_account)
    Account.any_instance.stubs(:new_email_regex_enabled?).returns(true)
    controller_params = { 'notify_emails' => ['test.@gmail.com'], 'to_emails' => ['test1.@gmail.com'],
                          'cc_emails' => ['test(@gmail.com'], 'bcc_emails' => ['test)@gmail.com'],
                          'from_email' => 'test]@gmail.com'  }
    item = nil
    conversation = ConversationValidation.new(controller_params, item)
    refute conversation.valid?
    errors = conversation.errors.full_messages
    assert errors.include?('Cc emails array_invalid_format')
    assert errors.include?('To emails array_invalid_format')
    assert errors.include?('Bcc emails array_invalid_format')
    assert errors.include?('Notify emails array_invalid_format')
    assert errors.include?('From email invalid_format')
  ensure
    Account.any_instance.unstub(:new_email_regex_enabled?)
    Account.unstub(:current)
  end

  def test_emails_validation_valid_new_regex_enabled
    Account.stubs(:current).returns(Account.first || create_test_account)
    Account.any_instance.stubs(:new_email_regex_enabled?).returns(true)
    controller_params = { 'notify_emails' => ['<!--test@gmail.com-->', 'abc<a_b@gmail.com>', 'a@b.com', 'a.b.c@gmail.com'], 'to_emails' => ['test1@gmail.com'],
                          'cc_emails' => ['test@gmail.com'], 'bcc_emails' => ['test@gmail.com'],
                          'from_email' => 'a.b.c@gmail.com'  }
    item = nil
    conversation = ConversationValidation.new(controller_params, item)
    conversation.valid?
    errors = conversation.errors.full_messages
    refute errors.include?('Cc emails array_invalid_format')
    refute errors.include?('To emails array_invalid_format')
    refute errors.include?('Bcc emails array_invalid_format')
    refute errors.include?('Notify emails array_invalid_format')
    refute errors.include?('From email invalid_format')
  ensure
    Account.any_instance.unstub(:new_email_regex_enabled?)
    Account.unstub(:current)
  end

  def test_emails_validation_non_english_characters
    controller_params = { 'body' => 'test', 'notify_emails' => ['0_9flaadaagas <adgasg@fff.com>'], 'to_emails' => ['aasgasA0d<adgasg@fff.com>'],
                            'cc_emails' => ['Бургер Кинг<adgasg@fff.com>'], 'bcc_emails' => ['ÒÂÅÎÏÍÍÅ<adgasg@fff.com>'], 'from_email' => 'fggg@ddd.com'}
    item = nil
    conversation = ConversationValidation.new(controller_params, item)
    assert  conversation.valid?
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

  def test_cloud_file_errors
    controller_params = { 'to_emails' => ['aaaaa@bbbb.com'], 'cloud_file_ids' => [100, 200], 'body' => 'Text', 'include_original_attachments' => true }
    conversation = ConversationValidation.new(controller_params, nil)
    refute conversation.valid?(:forward)
    errors = conversation.errors.full_messages
    assert errors.include?('Cloud file ids included_original_attachments')

    controller_params = { 'to_emails' => ['aaaaa@bbbb.com'], 'cloud_file_ids' => [100, 200], 'include_original_attachments' => false }
    conversation = ConversationValidation.new(controller_params, nil)
    assert conversation.valid?(:forward)
  end

  def test_empty_body_in_forward
    controller_params = { 'to_emails' => ['aaaaa@bbbb.com'], 'include_quoted_text' => false }
    conversation = ConversationValidation.new(controller_params, nil)
    refute conversation.valid?(:forward)
    errors = conversation.errors.full_messages
    assert errors.include?('Body missing_field')

    controller_params = { 'to_emails' => ['aaaaa@bbbb.com'], 'include_quoted_text' => true }
    conversation = ConversationValidation.new(controller_params, nil)
    assert conversation.valid?(:forward)

    controller_params = { 'to_emails' => ['aaaaa@bbbb.com'], 'include_quoted_text' => true, 'full_text' => 'Text' }
    conversation = ConversationValidation.new(controller_params, nil)
    refute conversation.valid?(:forward)
    errors = conversation.errors.full_messages
    assert errors.include?('Body missing_field')
    assert errors.include?('Include quoted text cannot_be_set')

    controller_params = { 'to_emails' => ['aaaaa@bbbb.com'], 'body' => 'Text', 'full_text' => 'ABC' }
    conversation = ConversationValidation.new(controller_params, nil)
    refute conversation.valid?(:forward)
    errors = conversation.errors.full_messages
    assert errors.include?('Full text shorter_full_text')

    controller_params = { 'to_emails' => ['aaaaa@bbbb.com'], 'body' => 'ABC', 'full_text' => 'XYZ' }
    conversation = ConversationValidation.new(controller_params, nil)
    refute conversation.valid?(:forward)
    errors = conversation.errors.full_messages
    assert errors.include?('Full text invalid_full_text')

    controller_params = { 'to_emails' => ['aaaaa@bbbb.com'], 'body' => 'Text', 'full_text' => 'Sample Text' }
    conversation = ConversationValidation.new(controller_params, nil)
    assert conversation.valid?(:forward)
  end

  def test_boolean_errors
    controller_params = { 'to_emails' => ['aaaaa@dddd.com'], 'body' => 'Text', 'private' => 'ABC', 'incoming' => 'f', 'include_quoted_text' => 'yes', 'include_original_attachments' => 'no', 'send_survey' => 'ABC' }
    conversation = ConversationValidation.new(controller_params, nil)
    refute conversation.valid?
    errors = conversation.errors.full_messages
    assert errors.include?('Private datatype_mismatch')
    assert errors.include?('Incoming datatype_mismatch')
    assert errors.include?('Include quoted text datatype_mismatch')
    assert errors.include?('Include original attachments datatype_mismatch')
    assert errors.include?('Send survey datatype_mismatch')

    controller_params = { 'to_emails' => ['aaaaa@dddd.com'], 'body' => 'Text', 'private' => false, 'incoming' => false, 'include_quoted_text' => true, 'include_original_attachments' => true, 'send_survey' => true }
    conversation = ConversationValidation.new(controller_params, nil)
    assert conversation.valid?
  end

  def test_complex_fields_with_nil
    controller_params = { 'notify_emails' => nil, 'to_emails' => nil, 'cc_emails' => nil, 'bcc_emails' => nil, 'attachments' => nil, 'cloud_file_ids' => nil  }
    item = nil
    conversation = ConversationValidation.new(controller_params, item)
    refute conversation.valid?
    errors = conversation.errors.full_messages
    assert errors.include?('Notify emails datatype_mismatch')
    assert errors.include?('To emails datatype_mismatch')
    assert errors.include?('Bcc emails datatype_mismatch')
    assert errors.include?('Cc emails datatype_mismatch')
    assert errors.include?('Attachments datatype_mismatch')
    Account.unstub(:current)
  end

  def test_validate_cloud_files
    controller_params = { 'body' => Faker::Lorem.paragraph, 'cloud_files' => Faker::Lorem.word }
    conversation = ConversationValidation.new(controller_params, nil)
    refute conversation.valid?(:reply)
    errors = conversation.errors.full_messages
    assert errors.include?('Cloud files datatype_mismatch')

    controller_params = { 'body' => Faker::Lorem.paragraph, 'cloud_files' => [{'filename' => Faker::Lorem.word}] }
    conversation = ConversationValidation.new(controller_params, nil)
    refute conversation.valid?(:reply)
    errors = conversation.errors.full_messages
    assert errors.include?('Cloud files is invalid')
  end
end
