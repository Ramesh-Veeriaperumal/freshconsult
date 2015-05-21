module Solution::LanguageMethods

	LANGUAGE_MAPPING = (
		I18n.available_locales.inject(HashWithIndifferentAccess.new) { |h,lang| h[lang] = I18n.t('meta', locale: lang); h }
	)

	def self.current_language_id
		portal = Portal.current || Account.current.main_portal
		supported_languages = [portal.language, Account.current.supported_languages].flatten
		current_language = supported_languages.include?(I18n.locale.to_s) ? I18n.locale : portal.language 
		LANGUAGE_MAPPING[current_language][:language_id]
	end

	def language=(value)
		self.language_id = LANGUAGE_MAPPING[value][:language_id]
	end

	def language
		language_code 
	end

	def language_code
		LANGUAGE_MAPPING.key(LANGUAGE_MAPPING.values.select { |x| x[:language_id] == language_id }.first)
	end

	def language_name
		LANGUAGE_MAPPING[language_code][:language_name]
	end	
end