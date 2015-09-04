module Solution::LanguageControllerMethods

	def short_name
		cname.gsub('solution_', '')
	end

	def language
		@language ||= Language.find(params[:language_id])
	end

	def language_scoper
		@language_scoper ||= "#{language.to_key}_#{short_name}"
	end

end