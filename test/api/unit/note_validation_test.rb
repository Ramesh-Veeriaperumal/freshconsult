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
end
