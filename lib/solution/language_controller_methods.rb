module Solution::LanguageControllerMethods

	def self.included(base)
    base.send :before_filter, :language, :only => [ :new, :create ]
  end

  protected

		def short_name
			cname.gsub('solution_', '')
		end

		def language
			@language ||= (Language.find(params[:language_id]) || Language.find_by_code(params[:language]) || Language.for_current_account)
		end

		def language_scoper
			@language_scoper ||= (language == Language.for_current_account ? "primary_#{short_name}" : "#{language.to_key}_#{short_name}")
		end

end