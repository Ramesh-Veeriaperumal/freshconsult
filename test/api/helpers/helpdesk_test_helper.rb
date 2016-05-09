module HelpdeskTestHelper
	def helpdesk_languages_pattern(expected_output = {}, ignore_extra_keys = true, account)
		portal_languages = account.account_additional_settings.additional_settings[:portal_languages]
		portal = portal_languages ? get_language_hash(portal_languages) : {}
		result = {
			primary_language:  expected_output[:primary_language] || get_language_hash(account.language),
			supported_languages:  expected_output[:supported_languages] || get_language_hash(account.account_additional_settings.supported_languages),
			portal_languages:  expected_output[:portal_languages] || portal
		}
	end

	def get_language_hash(keys)
    Language.all.map { |x| [x.code, x.name] }.to_h.slice(*keys)
  end
end