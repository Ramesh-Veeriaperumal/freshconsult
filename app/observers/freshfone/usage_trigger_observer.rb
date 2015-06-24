class Freshfone::UsageTriggerObserver < ActiveRecord::Observer
	observe Freshfone::UsageTrigger

	def before_destroy(freshfone_usagetrigger)
  	Resque.enqueue(Freshfone::Jobs::UsageTrigger,
  		delete_daily_credit_options(freshfone_usagetrigger)) if freshfone_usagetrigger.daily_credit_threshold?
	end

	def delete_daily_credit_options(ff_usagetrigger)
	{
		:delete => true,
		:trigger_sid => ff_usagetrigger.sid,
		:account_id => ff_usagetrigger.account_id
	}
	end
	
end
