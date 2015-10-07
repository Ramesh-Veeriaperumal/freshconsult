require_relative '../unit_test_helper'

class NoteValidationTest < ActionView::TestCase
  def test_numericality
    controller_params = { 'user_id' => 1 }
    item = nil
    note = NoteValidation.new(controller_params, item)
    assert note.valid?(:create)
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
    controller_params = { 'user_id' => 1, attachments: ["file.png"] }
    item = nil
    note = NoteValidation.new(controller_params, item)
    refute note.valid?
    errors = note.errors.full_messages
    assert errors.include?('Attachments data_type_mismatch')
    assert errors.count == 1
    Account.unstub(:current)
    Helpers::TicketsValidationHelper.unstub(:attachment_size)
  end
end
