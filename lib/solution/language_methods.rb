module Solution::LanguageMethods
	
	extend ActiveSupport::Concern

	included do
		scope :find_by_language, lambda { |lang| {:conditions => {:language_id => 
			Language.find_by_code(lang).id }}}
	end

	def language_obj
		Language.find(language_id)
	end

	def language=(value)
		self.language_id = Language.find_by_code(value).id
	end

	def language
		language_code 
	end

	def language_code
		language_obj.code
	end

	def language_name
		language_obj.name
	end

end