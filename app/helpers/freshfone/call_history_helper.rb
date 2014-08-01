module Freshfone::CallHistoryHelper
	include Carmen
	def sort_by_primary_filters
		[
			[ t('freshfone.call_history.received_date'), 'created_at' ], 
			[ t('freshfone.call_history.duration'), 'call_duration' ], 
			[ t('freshfone.call_history.cost'), 'call_cost' ]
		]
	end

	def sort_by_secondary_filters
		[
			[ t('freshfone.call_history.asc'), :asc ], 
			[ t('freshfone.call_history.desc'), :desc]
		]
	end

	def filtered_by_options
		[
			[ t('freshfone.call_history.today'), :today ], 
			[ t('freshfone.call_history.yesterday'), :yesterday ], 
			[ t('freshfone.call_history.this_week'), :week ], 
			[ t('freshfone.call_history.this_month'), :month ],
			[ t('freshfone.call_history.month', {:month => 2}), :two_months ],
			[ t('freshfone.call_history.month', {:month => 6}), :six_months ],
			[ t('freshfone.call_history.all_time'), '' ]
		]
	end

	def call_status_title(call)
		case call.call_status
		when Freshfone::Call::CALL_STATUS_HASH[:'no-answer']
			(call.incoming? ? t('freshfone.call_status.missedcall') : t('freshfone.call_status.noanswer'))
		when Freshfone::Call::CALL_STATUS_HASH[:'in-progress']
			t("freshfone.call_status.in_progress")
		else
			status = Freshfone::Call::CALL_STATUS_REVERSE_HASH[call.call_status]
			t("freshfone.call_status.#{status}")
		end
	end

	def blocked_number?(number)
		@blacklist_numbers.include? number.gsub(/^\+/, '')
	end

	def country_name(country_code)
		country = Country.coded(country_code)
		country ? country.name : nil
	end

	def call_duration_formatted(duration)
		format = (duration >= 3600) ? "%H:%M:%S" : "%M:%S"
		Time.at(duration).gmtime.strftime(format)
	end
end
