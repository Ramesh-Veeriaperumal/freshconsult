module Admin::Freshfone::NumbersHelper

	def multiple_hours_enabled?
		feature?(:multiple_business_hours) and 
			current_account.business_calendar.count > 1
	end

	def number_type(number)
		return if number.local?
		t('freshfone.admin.toll_free')
	end

	def max_queue_length_options
		[
			["3 Calls", 3],
			["5 Calls", 5],
			["10 Calls", 10]
		]
	end

	def queue_wait_time_options
		[
			["2 mins", 2],
			["5 mins", 5],
			["10 mins", 10],
			["15 mins", 15]
		]
	end

end