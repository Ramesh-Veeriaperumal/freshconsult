module OnboardingTestHelper
  def assert_channel_selection(channel)
    channel_assertion_method_name = "assert_#{channel}_channel"
    send(channel_assertion_method_name) if respond_to?(channel_assertion_method_name)
  end

  ['phone', 'social'].each do |channel|
    define_method("assert_#{channel}_channel") do
      @account.reload
      additional_settings = @account.account_additional_settings.additional_settings
      assert additional_settings["enable_#{channel}".to_sym], "Expected #{channel} channel to be enabled"
    end
  end

  def assert_forums_channel
    assert @account.features_included?(:forums), 'Expected forums channel to be enabled'
  end

  def forward_email_confirmation_pattern(confirmation_code, email)
    {
      confirmation_code: confirmation_code,
      email: email
    }
  end

  def anonymous_to_trial_success_pattern(email)
    @email = Mail::Address.new(email)
    {
      first_name: name_from_email,
      last_name: name_from_email,
      admin_email: email,
      company_name: company_name_from_email,
      anonymous_account: false
    }
  end

  def name_from_email
    @email.local.tr('.', ' ')
  end

  def company_name_from_email
    Freemail.free?(@email.address) ? name_from_email : @email.domain.split('.').first
  end

  def validation_error_pattern(value)
    {
      description: 'Validation failed',
      errors: [value]
    }
  end

  def request_error_pattern(expected_output)
    {
      code: expected_output[:code],
      message: expected_output[:message]
    }
  end
end
