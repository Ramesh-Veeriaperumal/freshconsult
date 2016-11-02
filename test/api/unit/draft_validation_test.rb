require_relative '../unit_test_helper'

class DraftValidationTest < ActionView::TestCase
  def test_empty_body
    draft_validation = DraftValidation.new({}, nil)
    refute draft_validation.valid?(:save_draft)
    errors = draft_validation.errors.full_messages
    assert errors.include?('Body datatype_mismatch')
  end

  def test_array_validation
    controller_params = { body: 'Sample Text', cc_emails: 'ABC', bcc_emails: 'XYZ', attachment_ids: '123' }
    draft_validation = DraftValidation.new(controller_params, nil)
    refute draft_validation.valid?(:save_draft)
    errors = draft_validation.errors.full_messages
    assert errors.include?('Cc emails datatype_mismatch')
    assert errors.include?('Bcc emails datatype_mismatch')
    assert errors.include?('Attachment ids datatype_mismatch')
  end

  def test_draft_validation
    controller_params = { body: 'Sample Text', cc_emails: ['AB <example@xyz.com>', 'xyz@example.com'], bcc_emails: ['<example2@xyz.com>'], from_email: 'zee@company.com', attachment_ids: [1,2] }
    draft_validation = DraftValidation.new(controller_params, nil)
    assert draft_validation.valid?(:save_draft)
  end
end
