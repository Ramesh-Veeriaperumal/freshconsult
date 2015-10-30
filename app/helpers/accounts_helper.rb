module AccountsHelper 
  
	def breadcrumbs
		_output = []
		_output << pjax_link_to(t('helpdesk_title'), edit_account_path)
		_output << t('accounts.multilingual_support.manage_languages')
		"<span class='manage_languages_breadcrumb breadcrumb'>#{_output.map{ |bc| "<li>#{bc}</li>" }.join("")}</span>".html_safe
	end

	def secondary_languages
		array = []
		@account.supported_languages.each do |l|
			array << Language.find_by_code(l).name
		end
		array.join(', ')
	end
  
end
