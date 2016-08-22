module HelpdeskTestHelper
	def helpdesk_languages_pattern(expected_output = {}, ignore_extra_keys = true, account)
		result = {
			primary_language: account.language,
			supported_languages:  account.supported_languages.to_a,
			portal_languages:  account.portal_languages.to_a
		}
	end
end