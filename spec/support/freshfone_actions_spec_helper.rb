module FreshfoneActionsSpecHelper
	def create_test_usage_triggers
		values = [75, 200]
		values.each	do |val|
			Freshfone::UsageTrigger.create(
      :account => @account,
      :freshfone_account => @account.freshfone_account,
      :sid => 'TRIGRSID',
      :trigger_type => :daily_credit_threshold,
      :start_value => 0,
      :trigger_value => val)
		end
	end
end