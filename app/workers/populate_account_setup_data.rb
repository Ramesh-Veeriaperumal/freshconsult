class PopulateAccountSetupData < BaseWorker

	include Marketplace::ApiUtil

	sidekiq_options :queue => :populate_account_setup, :retry => 0, :failures => :exhausted

	DEFAULT_AUTOMATION_RULES_COUNT = {
		:scn_automations => 3,
		:va_rules =>  1,
		:supervisor_rules => 1,
		:observer_rules => 2
	}

	def perform
		Account::Setup::KEYS.each do |setup_key|
			Account.current.safe_send("mark_#{setup_key}_setup") if safe_send("#{setup_key}_markable?")
		end
		Account.current.save_setup
	end
	
	private

	def new_account_markable?
		true
	end

	def account_admin_email_markable?
		Account.current.verified?
	end

	def agents_markable?
		Account.current.agents.count > 1
	end

	def support_email_markable?
		(Account.current.email_configs.count > 1 ? true : 
			(Account.current.primary_email_config.reply_email != "support@#{Account.current.full_domain}"))
	end

	def automation_markable?
		DEFAULT_AUTOMATION_RULES_COUNT.keys.each do |va_rule_type|
			return true if Account.current.safe_send("all_#{va_rule_type}").count != DEFAULT_AUTOMATION_RULES_COUNT[va_rule_type]
		end
		false
	end

	def data_import_markable?
		false
	end	

	def custom_app_markable?
		((Account.current.installed_applications.count > 0) || installed_extensions.present?)
	end

	def installed_extensions
		begin
			api_endpoint = Marketplace::ApiEndpoint::ENDPOINT_URL[:installed_extensions] %
					{ :product_id => Marketplace::Constants::PRODUCT_ID,
						:account_id => Account.current.id}
			extension_type = "#{Marketplace::Constants::EXTENSION_TYPE[:plug]},#{Marketplace::Constants::EXTENSION_TYPE[:custom_app]}"
			api_payload = account_payload(api_endpoint, nil, { type: extension_type })
			get_api(api_payload, MarketplaceConfig::ACC_API_TIMEOUT)
		rescue *FRESH_REQUEST_EXP => e
			exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
		end
	end

	def twitter_markable?
		Account.current.twitter_handles.count > 0
	end

	def freshfone_number_markable?
		Account.current.all_freshfone_numbers.count > 0
	end
end
