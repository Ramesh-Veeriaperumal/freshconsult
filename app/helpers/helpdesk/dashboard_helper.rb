module Helpdesk::DashboardHelper
  include MemcacheKeys

  TOOLBAR_LINK_OPTIONS = {
    "data-remote"         => true, 
    "data-method"         => :get,
    "data-response-type"  => "script",
    "data-loading-box"    => "#agents-list" 
  }

  PLAN_TYPE_MAPPING = {
    :sprout             =>  "type1",
    :pro                =>  "type1",
    :premium            =>  "type1",
    :basic              =>  "type1",
    :sprout_classic     =>  "type1",
    :blossom            =>  "type2",
    :blossom_classic    =>  "type2",
    :garden            =>   "type2",
    :garden_classic     =>  "type2",
    :estate             =>  "type2",
    :estate_classic     =>  "type2",
    :forest             =>  "type2"
  }

  DASHBOARD_WIDGETS = { 
    "type1" => {
      :widgets => [# ['NAME', XSIZE, YSIZE]
        [:activity, 2, 4],
        [:todo, 1, 1],
        # [:unresolved_tickets_by_group_id, 1, 1],
        [:phone, 1, 1],
        [:agent_status, 1, 1]
      ]
    },

    "type2" => {
      :widgets => [# ['NAME', XSIZE, YSIZE]
        [:activity, 2, 6],
        [:todo, 1, 1],
        # [:unresolved_tickets_by_group_id, 1, 1],
        [:phone, 1, 1],
        [:chat, 1, 1],
        [:agent_status, 1, 1],
        [:gamification, 1, 1],
        [:forum_moderation, 1, 1]
      ]
    },

    "type3" => {
      :widgets => [# ['NAME', XSIZE, YSIZE]
        [:activity, 1, 2],
        [:unresolved_tickets_by_group_id, 1, 1],
        [:unresolved_tickets_by_status, 1, 1],
        [:unresolved_tickets_by_priority, 1, 1],
        [:unresolved_tickets_by_ticket_type, 1, 1],
        [:phone, 1, 1],
        [:chat, 1, 1],
        [:agent_status, 1, 1],
        [:todo, 1, 1],
        [:gamification, 1, 1],
        [:forum_moderation, 1, 1]
      ]
    }
  }

  ALL_WIDGET_TYPE = "type3"

  def check_widget_privilege
    privilege_object = {
      :unresolved_tickets_by_group_id     =>  (@manage_dashboard && @global_dashboard && current_user.privilege?(:view_reports)),
      :unresolved_tickets_by_status       =>  true,
      :unresolved_tickets_by_priority     =>  true,
      :unresolved_tickets_by_ticket_type  =>  true,
      :activity                           =>  true,
      :todo                               =>  true,
      :gamification                       =>  (gamification_feature?(current_account)),
      :phone                              =>  (current_account.freshfone_active?),
      :chat                               =>  (chat_activated? && current_account.chat_setting.active),
      :forum_moderation                   =>  (current_account.features?(:forums) && privilege?(:delete_topic)),
      :agent_status                       =>  (round_robin? || current_account.freshfone_active? || (chat_activated? && current_account.chat_setting.active))
    }
    privilege_object
  end

  def widget_list
    type = PLAN_TYPE_MAPPING[current_account.plan_name]
    #type = ALL_WIDGET_TYPE if current_account.features?(:custom_dashboard)
    dashboard_widget = DASHBOARD_WIDGETS[type][:widgets]

    privilege = check_widget_privilege
    widget_object = Dashboard::Grid.new
    widgets = widget_object.process_widgets(dashboard_widget, privilege, type)

    widgets
  end

  def render_dashboard_widget( widget )
    render :partial => "/helpdesk/realtime_dashboard/#{widget.name}", 
            :locals => { :width => widget.width, :height => widget.height, :x => widget.x, :y => widget.y }
  end

  def realtime_dashboard?
    current_account.features?(:custom_dashboard)
  end


  def find_activity_url(activity)
    activity_data = activity.activity_data
    (activity.activity_data_blank? || activity_data[:path].nil? ) ? activity.notable : activity_data[:path]
  end

  def complimentary_demo_link
    demo_content = content_tag(:p, t('hard_pressed_for_time') )

    demo_content.concat(content_tag(:p,
        content_tag(:b, link_to( t('schedule_a_complimentary_session').html_safe, 
            "https://freshdesk.com/demo-request",
            :onclick => "window.open(this.href);return false;", :target => "_blank" ) )
        ))
  end

  def group_list_filter
    filter_list = current_account.groups.round_robin_groups.map{ |grp|
      [grp.name,"?group_id=#{grp.id}",false]
    }
    dropdown_menu(filter_list, TOOLBAR_LINK_OPTIONS)
  end

  def chat_activated?
    !current_account.subscription.suspended? && feature?(:chat) && !!current_account.chat_setting.display_id
  end

  def chat_active?
    chat_activated? and current_user.privilege?(:admin_tasks) and current_account.chat_setting.active
  end

  def groups
    current_account.groups_from_cache
  end

  def ffone_user_list
    @freshfone_agents.map { |agent| 
      {   
        :id             => agent.user_id,
        :name           => agent.name,
        :last_call_time => (agent.last_call_at),
        :presence       => agent.presence,
        :on_phone       => agent.available_on_phone,
        :avatar         => user_avatar(agent.user, 'thumb', 'preview_pic thumb'),
        :preference     => agent.incoming_preference
      }
    }.to_json
  end

  def available_rr_agents_count
    group_ids = current_account.groups.round_robin_groups.select(:id).map(&:id)
    return 0 if group_ids.blank?
    user_ids = current_account.agent_groups.where(group_id:group_ids).select(&:user_id).map(&:user_id).uniq
    user_ids.present? ? current_account.agents.where(available:true,user_id:user_ids).count :  0
  end

  def current_group
    @freshfone_group_current
  end    

  def round_robin?
    @round_robin_enabled ||=
      current_user.privilege?(:admin_tasks) and
      current_account.features?(:round_robin) and
      current_account.groups.round_robin_groups.any?      
  end

  def freshfone_active?
    @freshfone_enabled ||=
      current_user.privilege?(:admin_tasks) and
      current_account.freshfone_active?
  end

  def accessible_groups
    all_groups = {"-" => "All Groups"}
    groups = if current_user.restricted?
      agent_groups = current_user.agent_groups.includes(:group)
      agent_groups.inject({}) do |group_hash, agent_group|
        group_hash.merge!(agent_group.group.id => agent_group.group.name)
      end
    else
      Account.current.groups_from_cache.collect { |g| [g.id, g.name]}.to_h
    end
    all_groups.merge(groups)
  end

  def achivements_memcache_key
    MemcacheKeys.memcache_local_key(LEADERBOARD_MINILIST_REALTIME)
  end

	def freshfone_indicator_class
		load_warnings
		return 'expired ficon-warning' if freshfone_trial_expired?
		return 'low_credit ficon-warning' if !freshfone_trial_states? && freshfone_below_threshold?
		return 'normal' unless @show_warnings
		'warning tooltip ficon-warning'
	end

	def load_warnings
		@show_warnings = freshfone_subscription.present? && freshfone_subscription.trial_warnings? && freshfone_trial?
	end

	def freshfone_warnings
		return unless @show_warnings
		"#{freshfone_trial_incoming_warning}
		#{freshfone_trial_outgoing_warning}
		#{freshfone_trial_period_warning}".html_safe
	end

	def freshfone_warning_msg
		return t('freshfone.dashboard.trial.expired_title') if freshfone_trial_expired?
		return t('freshfone.dashboard.trial.title') if freshfone_trial?
		t('freshfone.dashboard.low_credit') if freshfone_below_threshold?
	end

	def freshfone_trial_incoming_warning
		return "#{t('freshfone.dashboard.trial.inbound_minutes_left.other', minutes: 0) }<br/>" if
			freshfone_subscription.inbound_usage_exceeded?
		return unless freshfone_subscription.incoming_warning?
		mins_left = pending_minutes_helper(
				freshfone_subscription.pending_incoming_minutes)
		return "#{t('freshfone.dashboard.trial.inbound_minutes_left.one')}<br/>" if
			mins_left == 1 # for singulartiy
		"#{t('freshfone.dashboard.trial.inbound_minutes_left.other',
			minutes: mins_left)}<br/>"
	end

	def freshfone_trial_outgoing_warning
		return "#{t('freshfone.dashboard.trial.outbound_minutes_left.other', minutes: 0)}<br/>" if
			freshfone_subscription.outbound_usage_exceeded?
		return unless freshfone_subscription.outgoing_warning?
		mins_left = pending_minutes_helper(
				freshfone_subscription.pending_outgoing_minutes)
		return "#{t('freshfone.dashboard.trial.outbound_minutes_left.one')}<br/>" if
			mins_left == 1 # for singularity
		"#{t('freshfone.dashboard.trial.outbound_minutes_left.other',minutes: mins_left)}<br/>"
	end

	def freshfone_trial_period_warning
		return "#{t('freshfone.dashboard.trial.trial_days_left.other', days: 0)}<br/>" if
			freshfone_subscription.trial_expired? || freshfone_trial_expired? # for edge case
		return unless freshfone_subscription.about_to_expire?
		days_left = freshfone_subscription.trial_period_left
		return "#{t('freshfone.dashboard.trial.trial_days_left.one')}<br/>" if
			days_left == 1 # for singularity
		"#{t('freshfone.dashboard.trial.trial_days_left.other', days: days_left)}<br/>"
	end

	def show_indicator?
		freshfone_trial_states? || freshfone_below_threshold?
	end

	def show_activate?
		(freshfone_trial_expired? ||
			(freshfone_trial? && freshfone_subscription.trial_limits_breached?))
	end

	def pending_minutes_helper(pending_minutes)
		(pending_minutes > 0) ? pending_minutes : 0
	end

  def credit_low_toggle
    'hide' unless (!freshfone_trial_states? && freshfone_below_threshold?)
  end
end
