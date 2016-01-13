require_relative '../unit_test_helper'

class NoteValidationTest < ActionView::TestCase
  def test_numericality
    controller_params = { 'user_id' => 1,  body: Faker::Lorem.paragraph }
    item = nil
    note = NoteValidation.new(controller_params, item)
    assert note.valid?(:create)
  end

  def test_body
    controller_params = { 'user_id' => 1 }
    item = nil
    note = NoteValidation.new(controller_params, item)
    refute note.valid?(:create)
    assert note.errors.full_messages.include?('Body missing')
    refute note.errors.full_messages.include?('Body html data_type_mismatch')

    controller_params = { 'user_id' => 1, body: '', body_html: '' }
    item = nil
    note = NoteValidation.new(controller_params, item)
    refute note.valid?(:create)
    assert note.errors.full_messages.include?('Body blank')
    refute note.errors.full_messages.include?('Body html data_type_mismatch')

    controller_params = { 'user_id' => 1, body: true, body_html: true }
    item = nil
    note = NoteValidation.new(controller_params, item)
    refute note.valid?(:create)
    assert note.errors.full_messages.include?('Body data_type_mismatch')
    assert note.errors.full_messages.include?('Body html data_type_mismatch')
  end

  def test_emails_validation_invalid
    controller_params = { 'notify_emails' => ['fggg@ddd.com,ss@fff.com'], 'cc_emails' => ['fggg@ddd.com,ss@fff.com'], 'bcc_emails' => ['fggg@ddd.com,ss@fff.com']  }
    item = nil
    note = NoteValidation.new(controller_params, item)
    refute note.valid?
    errors = note.errors.full_messages
    assert errors.include?('Cc emails not_a_valid_email')
    assert errors.include?('Bcc emails not_a_valid_email')
    assert errors.include?('Notify emails not_a_valid_email')
  end

  def test_attachment_multiple_errors
    Account.stubs(:current).returns(Account.first)
    String.any_instance.stubs(:size).returns(20_000_000)
    Helpers::TicketsValidationHelper.stubs(:attachment_size).returns(100)
    controller_params = { 'user_id' => 1, attachments: ['file.png'],  body: Faker::Lorem.paragraph }
    item = nil
    note = NoteValidation.new(controller_params, item)
    refute note.valid?
    errors = note.errors.full_messages
    assert errors.include?('Attachments data_type_mismatch')
    assert errors.count == 1
    Account.unstub(:current)
    Helpers::TicketsValidationHelper.unstub(:attachment_size)
  end

  def test_complex_fields_with_nil
    controller_params = { 'notify_emails' => nil, 'cc_emails' => nil, 'bcc_emails' => nil, attachments: nil  }
    item = nil
    note = NoteValidation.new(controller_params, item)
    refute note.valid?
    errors = note.errors.full_messages
    assert errors.include?('Notify emails data_type_mismatch')
    assert errors.include?('Bcc emails data_type_mismatch')
    assert errors.include?('Cc emails data_type_mismatch')
    assert errors.include?('Attachments data_type_mismatch')
    Account.unstub(:current)
  end
end
