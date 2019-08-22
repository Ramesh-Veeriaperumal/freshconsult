require_relative '../../../unit_test_helper'
class Notifications::Email::SettingsValidationTest < ActionView::TestCase
  def create_valid_update_params
    {
      emails: [
        'test@test.com',
        'test1@test.com'
      ]
    }
  end

  def test_success_with_valid_params
    bcc_email = Notifications::Email::BccValidation.new(create_valid_update_params)
    assert bcc_email.valid?(:update)
  end

  def test_failure_when_emails_are_not_sent_as_an_array
    email = create_valid_update_params
    email[:emails] = 'test@test.com, test1@test.com'
    bcc_email = Notifications::Email::BccValidation.new(email)
    refute bcc_email.valid?(:update)
    errors = bcc_email.errors.full_messages
    assert errors.include?('Emails datatype_mismatch')
  end

  def test_failure_when_emails_arent_a_string
    email = create_valid_update_params
    email[:emails] = [1234]
    bcc_email = Notifications::Email::BccValidation.new(email)
    refute bcc_email.valid?(:update)
    errors = bcc_email.errors.full_messages
    assert errors.include?('Emails array_datatype_mismatch')
  end
end
