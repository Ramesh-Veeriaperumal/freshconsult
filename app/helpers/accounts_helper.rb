module AccountsHelper 
	LANGUAGES_LIMIT = 3
  
	def breadcrumbs
		_output = []
		_output << pjax_link_to(t('helpdesk_title'), edit_account_path)
		_output << t('accounts.multilingual_support.manage_languages')
		"<span class='manage_languages_breadcrumb breadcrumb'>#{_output.map{ |bc| "<li>#{bc}</li>" }.join("")}</span>".html_safe
	end

	def languages_listing list
		content = ""
		if list.length == LANGUAGES_LIMIT + 1
			content << list.join(', ')
		else
			content << list.first(LANGUAGES_LIMIT).join(', ')
			content << more_languages(list[LANGUAGES_LIMIT..-1])
		end
	  content.html_safe
	end

	def more_languages list
		return "" unless list.present?
		%{
      <span
      	class="tooltip"
      	data-html="true"
      	data-placement="below"
      	title="#{populate_language_list(list)}">
     		#{t('accounts.multilingual_support.more_languages', :count => list.size)}</span>
	    }
	end

	def populate_language_list list
		output = []
		list.each do |lang|
			output << "<div>#{h(lang)}</div>"
		end
		output.join.html_safe
	end
  
end
