module Admin::Freshfone::NumbersHelper

	def multiple_hours_enabled?
		current_account.multiple_business_hours_enabled? and 
			current_account.business_calendar.count > 1
	end

	def number_type(number)
		return t('freshfone.admin.local') if number.local?
		return t('freshfone.admin.mobile') if number.mobile?
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

	def modify_options_for_trial(options)
    return options unless freshfone_trial_states?
    options.reject do |option|
      option[1] == Freshfone::Option::PERFORMER_TYPE_HASH[:call_number]
    end
  end

  def buy_number_link_helper
    return unless feature?(:freshfone)
    link_to(
      t('freshfone.admin.numbers.buy'),
      search_admin_freshfone_index_path,
      class: 'btn btn-primary')
  end

  def trial_number_limit_exceeded?
    !Freshfone::Subscription.number_purchase_allowed?(current_account)
  end

  def error_helper
    'error' if freshfone_trial_expired? || incoming_usage_exceeded? || outgoing_usage_exceeded?
  end

  def trial_state_heading_helper
    return t('freshfone.admin.trial.numbers.expired') if freshfone_trial_expired?
    return t('freshfone.admin.trial.numbers.free_minutes_exhausted') if usage_exceeded?
    return t('freshfone.admin.trial.numbers.outgoing_minutes_exhausted') if outgoing_usage_exceeded?
    return t('freshfone.admin.trial.numbers.incoming_minutes_exhausted') if incoming_usage_exceeded?
    t('freshfone.admin.trial.numbers.normal_trial_usage')
  end

  def trial_state_description_helper
    return t('freshfone.admin.trial.numbers.cannot_make_or_receive_calls') if freshfone_trial_expired? || usage_exceeded?
    return t('freshfone.admin.trial.numbers.outgoing_minutes_exhausted_description') if outgoing_usage_exceeded?
    return t('freshfone.admin.trial.numbers.incoming_minutes_exhausted_description') if incoming_usage_exceeded?
    t('freshfone.admin.trial.numbers.activate_to_use_all')
  end

  def incoming_limit_hash
    { total: freshfone_subscription.inbound[:minutes], used: usage_helper }
  end

  def outgoing_limit_hash
    { total: freshfone_subscription.outbound[:minutes], used: usage_helper(Freshfone::Call::CALL_TYPE_HASH[:outgoing]) }
  end

  def usage_helper(type = Freshfone::Call::CALL_TYPE_HASH[:incoming])
    if type == Freshfone::Call::CALL_TYPE_HASH[:incoming]
      incoming_usage_exceeded? ? freshfone_subscription.inbound[:minutes] : freshfone_subscription.calls_usage[:minutes][:incoming]
    else
      outgoing_usage_exceeded? ? freshfone_subscription.outbound[:minutes] : freshfone_subscription.calls_usage[:minutes][:outgoing]
    end
  end

  def incoming_usage_exceeded?
    freshfone_subscription.inbound_usage_exceeded? || (freshfone_subscription.pending_incoming_minutes <= 0)
  end

  def outgoing_usage_exceeded?
    freshfone_subscription.outbound_usage_exceeded? || (freshfone_subscription.pending_outgoing_minutes <= 0)
  end

  def usage_exceeded?
    incoming_usage_exceeded? && outgoing_usage_exceeded?
  end

  def active?
    ff_account = current_account.freshfone_account
    return if ff_account.blank?
    ff_account.active? || ff_account.trial? || ff_account.trial_exhausted?
  end

  def outgoing_caller(number)
		return number.freshfone_caller_id.id if number.freshfone_caller_id.present?
		return current_account.freshfone_caller_id.first.id if current_account.freshfone_caller_id.first.present?
		return {}
	end

end