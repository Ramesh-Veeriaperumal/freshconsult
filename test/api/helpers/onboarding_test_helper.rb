module OnboardingTestHelper

	def assert_channel_selection(channels)
		channels.each do |channel|
			channel_assertion_method_name = "assert_#{channel}_channel"
			send(channel_assertion_method_name) if respond_to?(channel_assertion_method_name)
		end
	end

	["phone", "social"].each do |channel|
		define_method("assert_#{channel}_channel") do
			@account.reload
			additional_settings = @account.account_additional_settings.additional_settings
			assert additional_settings["enable_#{channel}".to_sym], "Expected #{channel} channel to be enabled"
		end
	end

	def assert_forums_channel
		assert @account.features_included?(:forums), "Expected forums channel to be enabled"
	end

  	def forward_email_confirmation_pattern(confirmation_code, email)
  		{
  			confirmation_code: confirmation_code,
				email: email
  		}
	end
end
