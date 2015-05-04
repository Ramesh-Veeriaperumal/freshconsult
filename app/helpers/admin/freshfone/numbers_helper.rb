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
			["None", 0],
			["3", 3],
			["5", 5],
			["10", 10]
		]
	end

	def queue_wait_time_options
		[
			["1 min", 1],
			["2 mins", 2],
			["3 mins", 3],
			["4 mins", 4],
			["5 mins", 5],
			["10 mins", 10],
			["15 mins", 15]
		]
	end
	
	def accessible_groups(number)
		groups = []
		selected_number_group = number.freshfone_number_groups
		if selected_number_group
			selected_number_group.each do |number_group|
				groups << number_group.group_id
			end
		end
		groups
	end
end