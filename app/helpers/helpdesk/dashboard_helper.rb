module Helpdesk::DashboardHelper
  include Helpdesk::DashboardV2Helper
  include MemcacheKeys

  TOOLBAR_LINK_OPTIONS = {
    "data-remote"         => true, 
    "data-method"         => :get,
    "data-response-type"  => "script",
    "data-loading-box"    => "#agents-list" 
  }

  DEFAULT_DASHBOARDS_LABELS = [:standard, :agent, :supervisor, :admin]

  SETUP_KEY_UTILS = {
    "new_account" => {},
    "account_admin_email" => {:icon => "power"},
    "agents" => {:icon => "add-people", :path => "/agents"},
    "support_email" => {:icon => "support-email", :path => "/admin/email_configs"},
    "twitter" => {:icon => "twitter-o", :path => "/admin/social/streams"},
    "automation" => {:icon => "gear-line", :path => "/admin/va_rules"},
    "data_import" => {:icon => "contacts", :path => "/imports/contact"},
    "custom_app" => {:icon => "cube", :path => "/integrations/applications", :no_pjax => true},
    "freshfone_number" => {:icon => "ff-line-phone", :path => "/admin/phone/numbers" }
  }

  def widget_list snapshot
    dashboard_widget = dashboard_widget_list snapshot
    widget_object = Dashboard::Grid.new
    widgets = widget_object.process_widgets(dashboard_widget, snapshot)

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

  def group_list_filter(selected_group)
    filter_list = current_user.accessible_roundrobin_groups.order("name").map{ |grp|
      selected = (selected_group && selected_group.id == grp.id ? true : false)
      [grp.name,"?group_id=#{grp.id}",selected]
    }
    dropdown_menu(filter_list, TOOLBAR_LINK_OPTIONS)
  end

  def chat_activated?
    !current_account.subscription.suspended? && feature?(:chat) && !!current_account.chat_setting.site_id
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
    group_ids = current_user.accessible_roundrobin_groups.pluck(:id)
    return 0 if group_ids.blank?
    user_ids = current_account.agent_groups.where(:group_id => group_ids).pluck(:user_id).uniq
    user_ids.present? ? current_account.available_agents.where(:user_id => user_ids).count :  0
  end

  def current_group
    @freshfone_group_current
  end    

  def round_robin?
    @round_robin_enabled ||=
      (current_user.privilege?(:admin_tasks) or current_user.privilege?(:manage_availability)) and
      current_account.features?(:round_robin) and
      current_user.accessible_groups.round_robin_groups.any?
  end

  def freshfone_active?
    @freshfone_enabled ||=
      current_user.privilege?(:admin_tasks) and
      current_account.freshfone_active?
  end

  def dashboardv2_accessible_groups
    all_groups = {"-" => "All"}
    agent_groups = current_user.agent_groups.includes(:group)
    groups = agent_groups.inject({}) do |group_hash, agent_group|
        group_hash.merge!(agent_group.group.id => agent_group.group.name)
      end
    all_groups.merge(groups)
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

  def snapshot_menu
    options = [default_dashboard[0]]
    return options if !dashboardv2_available? || current_account.launched?(:es_down) #Show only Standard Dashboard if ES is down. This ideally shouldn't occur, fingers crossed.
    if current_user.privilege?(:admin_tasks)
      options << default_dashboard[3]
    elsif current_user.privilege?(:view_reports)
      options << default_dashboard[2]
    else
      options << default_dashboard[1]
    end
    options
  end

  def snapshot_label type
    translated_snapshot_label[type.to_sym]
  end

  def translated_snapshot_label
    @translated_snapshot_label_cache ||= Hash[*DEFAULT_DASHBOARDS_LABELS.map { |i| [i, I18n.t("helpdesk.realtime_dashboard.#{i}")] }.flatten]
  end

  def default_dashboard
    @default_dashboard_cache ||= DEFAULT_DASHBOARDS_LABELS.map do |d|
      { 
        name: translated_snapshot_label[d],
        param: d.to_s
      }
    end
  end

  # Helper to determine whether to show Group Drop Down
  def show_groups_selection? type
    (type == 'supervisor') and current_user.privilege?(:view_reports)
  end

  def in_setup_keys
    current_account.current_in_setup
  end

  def in_setup_keys_length
    current_account.current_in_setup.length
  end

  def total_setup_keys_length
    current_account.current_setup_keys.length
  end

  def configuration_percentage_complete
    @configuration_percentage_complete ||= ((in_setup_keys_length.to_f/total_setup_keys_length.to_f)*100).round
  end

  def setup_progress_text
    keys_mod = (in_setup_keys_length%total_setup_keys_length)
    if keys_mod > 1
      text_selector = ((total_setup_keys_length - keys_mod) == 1) ? "setup_progress_penultimate" : "setup_progress_misc"
    else
      text_selector = "setup_progress_#{keys_mod}"
    end
    t("accounts.setup.#{text_selector}")
  end

  def icon_for_setup_key setup_key
    "ficon-#{SETUP_KEY_UTILS[setup_key][:icon]}"
  end

  def path_for_setup_key setup_key
    path = SETUP_KEY_UTILS[setup_key][:path]
    (in_setup_keys.include?(setup_key) || path.blank?) ? "#" : path + "?ref=accountSetup"
  end

  def link_html_options(setup_key)
    link_html_options = SETUP_KEY_UTILS[setup_key][:no_pjax] ? { "target" => "_blank" } : {"data-pjax"=>"#body-container"}
    (path_for_setup_key(setup_key) == "#") ? { :class=> "setup-info-link disabled"} : link_html_options.merge(:class => "setup-info-link")
  end
end

