module Solution::LanguageMethods
	
	extend ActiveSupport::Concern

	def language
		Language.find(language_id)
	end

	def language=(value)
		self.language_id = Language.find_by_code(value).id
	end

	def language_code
		language.code
	end

	def language_key
		language.to_key
	end

	def language_name
		language.name
	end

end