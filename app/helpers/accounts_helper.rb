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
    list.collect { |lang| "<div>#{h(lang)}</div>" }.join.html_safe
  end

  def add_account_info_to_dynamo(signup_email)
    AccountInfoToDynamo.perform_async(email: signup_email)
  end

   def add_to_crm(account_id, signup_params = {})
    if Rails.env.production? || Rails.env.staging?
      Subscriptions::AddLead.perform_at(ThirdCRM::ADD_LEAD_WAIT_TIME.minute.from_now,
                                        account_id: account_id,
                                        signup_id: signup_params[:signup_id])
      CRMApp::Freshsales::Signup.perform_at(5.minutes.from_now,
                                            account_id: account_id,
                                            fs_cookie: signup_params[:fs_cookie])
    end
  end
end
