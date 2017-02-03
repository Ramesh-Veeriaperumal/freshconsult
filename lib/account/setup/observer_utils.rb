module Account::Setup::ObserverUtils

	private

	def mark_current_flag(object)
		current_flag = current_flag(object)
		Rails.logger.debug "::::::: Trial widget update : #{current_flag.humanize} set up :::::::" if account_object(object).subscription.trial?
		account_object(object).send("mark_#{current_flag}_setup_and_save")
	end
	
	def current_flag(object)
		setup_keys_for_model[object.class.name]
	end

	def current_flag_unmarked?(object) 
		!account_object(object).send("#{current_flag(object)}_setup?")
	end

	def account_object(object)
		((object.class.name == "Account") ? object : object.account)
	end
end