module Solution::LanguageControllerMethods

	def short_name
		cname.gsub('solution_', '')
	end

	def language
		@language ||= (Language.find(params[:language_id]) || Language.for_current_account)
	end

	def language_scoper
		@language_scoper ||= (language == Language.for_current_account ? "primary_#{short_name}" : "#{language.to_key}_#{short_name}")
	end

end