module AccountsHelper 
	LANGUAGES_LIMIT = 3
  TRUE_VALUES = [true, 1, '1', 'true', 'TRUE', 'on', 'ON'].to_set

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
                                            fs_cookie: signup_params[:fs_cookie]) unless Account.current.disable_freshsales_api_integration?
    end
  end

  def self.value_to_boolean(value)
    if value.is_a?(String) && value.empty?
      nil
    else
      TRUE_VALUES.include?(value)
    end
  end

  def manage_language_url
    current_account.falcon_ui_enabled?(current_user) ? '/a/admin/account/languages' : '/admin/manage_languages'
  end

  def translation_download_url(object_type, object_id = nil, language_code = nil)
    query_param = { object_type: object_type }
    query_param[:object_id] = object_id if object_id.present?
    query_param[:language_code] = language_code if language_code.present?
    "/api/_/admin/custom_translations?#{query_param.to_query}"
  end

  def precreated_account_signup_params
    signup_params = {}
    signup_params[:user] = {
      email: generate_demo_email,
      first_name: 'New',
      last_name: 'Account'
    }
    signup_params[:account] = { user: signup_params[:user] }
    [:user, :account].each do |param|
      signup_params[param].each do |key, value|
        signup_params["#{param}_#{key}"] = value
      end
    end
    domain_generator = DomainGenerator.new(signup_params[:user][:email], [], 'account_precreate')
    email_name = domain_generator.email_name
    signup_params[:locale] = 'en'
    signup_params['time_zone'] = 'Eastern Time (US & Canada)'
    signup_params[:direct_signup] = false
    signup_params['account_name']        ||= domain_generator.domain_name
    signup_params['account_domain']      ||= domain_generator.subdomain
    signup_params['contact_first_name']  ||= email_name
    signup_params['contact_last_name']   ||= email_name
    signup_params
  end

  def generate_demo_email
    current_time = (Time.now.utc.to_f * 1000).to_i
    "#{AccountConstants::ANONYMOUS_EMAIL}#{current_time}@example.com"
  end

  def fetch_precreated_account
    return unless redis_key_exists?(PRECREATE_ACCOUNT_ENABLED) && omni_precreated_signup_enabled?

    account_id = get_others_redis_rpop(format(PRECREATED_ACCOUNTS_SHARD, current_shard: ActiveRecord::Base.current_shard_selection.shard.to_s))
    if account_id.present?
      precreated_account = Account.find(account_id)
      precreated_account.make_current
      precreated_account.users.find(&:active).make_current
    end
    account_id
  rescue StandardError => e
    Rails.logger.error "Error in mapping precreated account - #{e.message}"
    nil
  end

  def omni_precreated_signup_enabled?
    omni_signup? ? redis_key_exists?(PRECREATE_OMNI_SIGNUP_ENABLED) : true
  end
end
