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

	def freshfone_numbers_options
		numbers_options = []
		numbers_options = @all_freshfone_numbers.map{|c|
			{ :id => c.id, :value => c.number, :deleted => c.deleted, :name => CGI.escapeHTML(c.name) }
		 }.to_json
	end

	def agents_list
		agents_list = []
		agents_list.concat(Account.current.agents_from_cache.map { |au| [ au.user.name, au.user.id] })
		agents_list
	end

	def groups_options
		groups_list_options = []
		groups_list_options =  current_account.groups.map { |group|
			{ :id => group.id, :value => group.name}
		  }.to_json
	end

	def filtered_by_time_options
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

	def filtered_by_call_status_options
		result = [
			{ :id =>0, :value => t('freshfone.call_history.filter_option_all_calls'), :call_type => '' },
			{ :id =>1, :value =>t('freshfone.call_history.filter_option_received_calls'), :call_type => 'received' },
			{ :id =>2, :value =>t('freshfone.call_history.filter_option_outgoing_calls'),:call_type => 'dialed' },
			{ :id =>3, :value =>t('freshfone.call_history.filter_option_missed_calls'), :call_type => 'missed' },
			{ :id =>4, :value =>t('freshfone.call_history.filter_option_voicemail'), :call_type => 'voicemail' },
			{ :id =>5, :value =>t('freshfone.call_history.filter_option_blocked_calls'), :call_type => 'blocked' }
		]
		result.to_json
	end

	def date_picker_labels
		[
			{ :today => t('freshfone.call_history.today') ,
			:yesterday =>t('freshfone.call_history.yesterday') ,
			:this_week => t('freshfone.call_history.this_week') ,
			:this_month => t('freshfone.call_history.this_month'),
			:custom => t('freshfone.call_history.custom') }
		].to_json
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
