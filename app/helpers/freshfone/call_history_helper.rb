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

	def numbers_hash
		@numbers ||=current_account.all_freshfone_numbers.reduce({}){|obj,c| obj.merge!({c.id=>c.number})}	
	end

	def link_to_caller(user, user_name, options = {})
	  return if user.blank?
	  if privilege?(:view_contacts)
   		default_opts = { :class => "username",
                       :rel => "contact-hover",
                       "data-contact-id" => user.id,
                       "data-contact-url" => hover_card_contact_path(user)  
                     }
      pjax_link_to(user_name, user, default_opts.merge(options))
    else
      content_tag(:strong, user_name , options)
    end
  end

  def trimmed_user_name(username)
  	username.length < 20 ? username : "#{username[0..16]}.."
  end
  	
	def freshfone_numbers_options
		numbers_options = []
		numbers_options = @all_freshfone_numbers.map{|c|
			{ :id => c.id, :value => c.number, :deleted => c.deleted, :name => CGI.escapeHTML(c.name.to_s) }
		 }
		numbers_options.unshift({:value => t('reports.freshfone.all_numbers'),:deleted=> false, :id=> 0 ,:name=> t('reports.freshfone.all_call_types')})
		numbers_options.to_json
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

	def filtered_by_business_hours_options
		result = [
			{ :id => 0, :value => t('freshfone.call_history.filter_option_all_calls'), :business_hour_call => '' },
			{ :id => 1, :value =>t('freshfone.call_history.filter_option_within_business_hours'), :business_hour_call => "true" },
			{ :id => 2, :value =>t('freshfone.call_history.filter_option_outside_business_hours'),:business_hour_call => "false" }
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
			(call.incoming? ?  abandon_status_or_missed(call) : t('freshfone.call_status.noanswer'))
		when Freshfone::Call::CALL_STATUS_HASH[:'in-progress']
			t("freshfone.call_status.in_progress")
		else
			status = Freshfone::Call::CALL_STATUS_REVERSE_HASH[call.call_status]
			t("freshfone.call_status.#{status}")
		end
	end

	def abandon_status_or_missed(call)
		if call.abandon_state.present?
			status = Freshfone::Call::CALL_ABANDON_TYPE_REVERSE_HASH[call.abandon_state]
			t("freshfone.call_status.#{status}") 
		else
			t('freshfone.call_status.missedcall')
		end
	end

	def blocked_number?(id)
		@blacklist_numbers.include?(id)
	end
	
	def country_name(country_code)
		country = Country.coded(country_code)
		country ? country.name : nil
	end


	def billing_duration(call)
		return 1 if (call.busy? || call.noanswer?)
		duration = call.total_duration  if (call.total_duration && call.total_duration != 0)
		duration = call.call_duration if (duration.blank? && call.call_duration && call.call_duration != 0)
		duration || 1
	end

	def call_duration_formatted(duration)
		if duration >= 3600
			"%02d:%02d:%02d" % [duration / 3600, (duration / 60) % 60, duration % 60]
		else
			"%02d:%02d" % [(duration / 60) % 60, duration % 60]
		end
	end

  def call_cost_splitup(call, pulse = 1)
    pulse_rate = call.pulse_rate
    duration = billing_duration(call)
    pulse = (duration.to_f/60).ceil if (duration.present? && (duration.to_f != 0))
    pulse
  end

  def call_cost_dom(call)
    return if call.missed_conf_transfer? || call.blocked?
    return content_tag(:b, nil, :class => "callhistory-payment-loader", :id => "ticket_list_count") if call.call_cost.blank?
    return "$#{call.call_cost}" unless current_account.features?(:freshfone_conference)
    content_tag(:span, "$#{call.call_cost}",:class => "ff_call_cost", :rel => "ff-cost-hover-popover", :data => {:total_duration => call_duration_formatted(billing_duration(call)), :no_of_unit => call_cost_splitup(call), :pulse_rate => call.pulse_rate })
  end
	
	def export_options
		[{ i18n: t('export_data.csv'), en: "CSV" }, { i18n: t('export_data.xls'), en: "Excel" }]
	end

	def export_messages
		{
			:success_message	=> t('export_data.call_history.info.success'),
			:error_message		=> t('export_data.call_history.info.error'),
			:range_limit_message => t('export_data.call_history.range_limit_message', range: Freshfone::Call::EXPORT_RANGE_LIMIT_IN_MONTHS )
		}
	end

  def recording_deleted_title(call)
  	if call.present? && call.recording_deleted_info.present?
  		"#{t("freshfone.call_history.recording_delete.done_by")} #{call.recording_deleted_by}, on #{formated_date(Time.zone.parse(call.recording_deleted_at.to_s))}"
  	end
  end

  def cannot_make_calls(classname = nil)
    content_tag :span, nil, {:class => "restrict-call #{classname}"}
  end

  def external_transfer?(call)
    return if call.meta.blank?
    call.meta.device_type == Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer]
  end
end
