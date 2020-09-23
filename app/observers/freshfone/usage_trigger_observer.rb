class Freshfone::UsageTriggerObserver < ActiveRecord::Observer
	observe Freshfone::UsageTrigger

	def before_destroy(freshfone_usagetrigger)
  	Resque.enqueue(
  		Freshfone::Jobs::UsageTrigger,
  		delete_daily_credit_options(freshfone_usagetrigger)) if preconditions?(freshfone_usagetrigger)
	end

	def delete_daily_credit_options(ff_usagetrigger)
	{
		:delete => true,
		:trigger_sid => ff_usagetrigger.sid,
		:account_id => ff_usagetrigger.account_id
	}
	end

	private

		def preconditions?(freshfone_usagetrigger)
			freshfone_usagetrigger.daily_credit_threshold? ||
				Freshfone::UsageTrigger::TRIAL_TRIGGERS.include?(freshfone_usagetrigger.trigger_type)
		end
		
end
