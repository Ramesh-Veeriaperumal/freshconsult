require_relative '../unit_test_helper'

class EmailNotificationValidationTest < ActionView::TestCase
  def test_invalid_notification
    Account.stubs(:current).returns(Account.new)
    notification_type = 1
    params = {
      notification_type: notification_type,
      requester_notification: 1234,
      agent_notification: 123,
      requester_template: 1234,
      requester_subject_template: 1234,
      agent_template: 1234,
      agent_subject_template: 1234
    }
    stub_email_notification_visibility(notification_type) do 
      email_notification_validation =  EmailNotificationValidation.new(params, EmailNotification.new)
      refute email_notification_validation.valid?
      errors = email_notification_validation.errors.full_messages
      assert errors.include?("Requester notification datatype_mismatch")
      assert errors.include?("Agent notification datatype_mismatch")
      assert errors.include?("Requester template datatype_mismatch")
      assert errors.include?("Requester subject template datatype_mismatch")
      assert errors.include?("Agent template datatype_mismatch")
      assert errors.include?("Agent subject template datatype_mismatch")
    end
    Account.unstub(:current)
  end

  def test_invalid_notification_with_empty
    Account.stubs(:current).returns(Account.new)
    notification_type = 1
    params = {
      notification_type: notification_type,
      requester_template: '',
      requester_subject_template: '',
      agent_template: '',
      agent_subject_template: ''
    }
    stub_email_notification_visibility(notification_type) do 
      email_notification_validation =  EmailNotificationValidation.new(params, EmailNotification.new)
      refute email_notification_validation.valid?
      errors = email_notification_validation.errors.full_messages
      assert errors.include?("Requester template can't be blank")
      assert errors.include?("Requester subject template can't be blank")
      assert errors.include?("Agent template can't be blank")
      assert errors.include?("Agent subject template can't be blank")
    end
    Account.unstub(:current)
  end

  def test_invalid_notification_without_requester_access
    Account.stubs(:current).returns(Account.new)
    stub_email_notification_visibility(default_params['notification_type'], false, true) do 
      email_notification_validation =  EmailNotificationValidation.new(default_params, EmailNotification.new)
      refute email_notification_validation.valid?
      errors = email_notification_validation.errors.full_messages
      assert errors.include?("Requester template inaccessible_field")
      assert errors.include?("Requester subject template inaccessible_field")
    end
    Account.unstub(:current)
  end

  def test_invalid_notification_without_agent_template_access
    Account.stubs(:current).returns(Account.new)
    stub_email_notification_visibility(default_params['notification_type'], true, false) do 
      email_notification_validation =  EmailNotificationValidation.new(default_params, EmailNotification.new)
      refute email_notification_validation.valid?
      errors = email_notification_validation.errors.full_messages
      assert errors.include?("Agent template inaccessible_field")
      assert errors.include?("Agent subject template inaccessible_field")
    end
    Account.unstub(:current)
  end

  def test_valid_notification
    Account.stubs(:current).returns(Account.new)
    stub_email_notification_visibility(default_params['notification_type']) do
      email_notification_validation =  EmailNotificationValidation.new(default_params.symbolize_keys, EmailNotification.new)
      valid = email_notification_validation.valid?
      assert valid
    end
    Account.unstub(:current)
  end

  private

    def stub_email_notification_visibility(notification_type, requester_accessible = true, agent_accessible = true)
      EmailNotification.stubs(:requester_visible_template?).with(notification_type).returns(requester_accessible)
      EmailNotification.stubs(:agent_visible_template?).with(notification_type).returns(agent_accessible)
      yield
      EmailNotification.unstub(:requester_visible_template?)
      EmailNotification.unstub(:agent_visible_template?)
    end

    def default_params
      {
        'notification_type' => 1,
        'requester_notification' => true, 
        'agent_notification' => true,
        'requester_template' => 'Test',
        'requester_subject_template' => 'Test',
        'agent_template' => 'Test',
        'agent_subject_template' => 'Test'
      }
    end
end