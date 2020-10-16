module HelpdeskReports::Helper::PlanConstraints

  attr_accessor :plan_group

  PLAN_GROUP_MAPPING = ReportsAppConfig::REPORT_CONSTRAINTS[:plan_groups].inject({}) do 
                        |h,(k,v)| v.each{ |i| h[i] = k }; h
                       end

  FEATURE_BASE_PLAN = {
    :enterprise_reporting => ['estate', 'forest']
  }

  PLAN_BASED_FEATURE_CONSTRAINT_MAPPING = {}

  PLAN_BASED_REPORTS = PLAN_BASED_FEATURE_CONSTRAINT_MAPPING.keys

  PLAN_BASED_CONSTRAINTS = PLAN_BASED_FEATURE_CONSTRAINT_MAPPING.values

  REPORTS_PLAN_BASED_URL_MAPPINGS = [
   [:high,    [:estate, :forest],   'high',   'high_bg'   ],
   [:medium,  [:blossom, :garden],  'medium', 'medium_bg' ],
   [:low,     [:sprout],            'low',    'low_bg'    ]
  ]

  REPORTS_PLAN_PRIORITY = REPORTS_PLAN_BASED_URL_MAPPINGS.map{|arr| [arr[0], arr[1]] }.to_h

  REPORTS_URL_SUFFIX    = REPORTS_PLAN_BASED_URL_MAPPINGS.map{|arr| [arr[0], arr[2]] }.to_h

  REPORTS_BG_URL_SUFFIX = REPORTS_PLAN_BASED_URL_MAPPINGS.map{|arr| [arr[0], arr[3]] }.to_h

  def plan_group
    return @plan_group if defined?(@plan_group)
    @plan_group ||= account_plan_name || :default
    if enterprise_reporting? && FEATURE_BASE_PLAN[:enterprise_reporting].exclude?(plan_group)
      @plan_group = FEATURE_BASE_PLAN[:enterprise_reporting].first
    end
    @plan_group
  end

  def account_plan_name
    @plan_name ||= Account.current.subscription.subscription_plan.display_name.downcase
  end
  
  ReportsAppConfig::REPORT_CONSTRAINTS[:plan_constraints].each do |constraint, plans| 
    define_method("#{constraint}?") do
      account_plan = PLAN_BASED_CONSTRAINTS.include?(constraint.to_sym) ? account_plan_name : plan_group
      Account.current.active? && (plans || []).include?(account_plan)
    end
  end

  def enterprise_reporting?
    # return @ent_reports_addon if defined?(@ent_reports_addon)
    @ent_reports_addon ||= Account.current.features_included?(:enterprise_reporting)
  end

  def hide_agent_reporting?
    return @hide_agent_metrics if defined?(@hide_agent_metrics)
    @hide_agent_metrics ||= Account.current.euc_hide_agent_metrics_enabled?
  end

  def plan_based_report?(report_type)
    PLAN_BASED_REPORTS.include?(report_type.to_sym)
  end

  def allowed_plan?(report_type)
    safe_send("#{PLAN_BASED_FEATURE_CONSTRAINT_MAPPING[report_type.to_sym]}?")
  end

  def exclude_filters(report_type)  
    excluded_filters  = []
    excluded_filters |= ReportsAppConfig::REPORT_CONSTRAINTS[:global_exclude_filters][report_type] || []
    plan_excludes     = ReportsAppConfig::REPORT_CONSTRAINTS[:plan_exclude_filters][report_type]
    plan_filters      = plan_excludes[plan_group] if plan_excludes
    excluded_filters |= plan_filters || [] 
    excluded_filters += [:agent_id] if hide_agent_reporting?
    excluded_filters += [:tag_id] if(report_type.to_sym == :timesheet_reports)
    excluded_filters += (report_type==:timespent) ? [:agent_id, :group_id] : [:is_escalated]
    excluded_filters
  end

  def max_limits_by_user?(feature, current_count = nil)
    max_limits?(feature, :user, current_count)
  end

  def max_limits_by_account?(feature, current_count = nil)
    max_limits?(feature, :account, current_count)
  end

  def max_limits?(feature, context = :account, current_count = nil)
    exceeded = true
    limit = max_limit(feature, context)
    if current_count.blank?
      custom_count_method = "#{feature}_#{context}_count".freeze
      current_count = safe_send(custom_count_method) if current_count.blank? && defined?(custom_count_method)
    end
    exceeded = (current_count >= limit) if (limit && current_count).is_a? Fixnum
    exceeded
  end

  def max_limit(feature, context)
    feature_limits = ReportsAppConfig::REPORT_CONSTRAINTS[:max_limits][feature] || {}
    limit = (feature_limits[context] || {})
    limit[plan_group] || limit[:default]
  end

  def data_refresh_frequency
    plan_frequency = (ReportsAppConfig::REPORT_CONSTRAINTS[:data_refresh_frequency][account_plan_name] || 1440)
    enterprise_reporting? ? [plan_frequency, ReportsAppConfig::REPORT_CONSTRAINTS[:data_refresh_frequency]['enterprise_reporting']].min : plan_frequency
  end

  def save_report_user_count
    @save_report_user_count ||= User.current.report_filters.count
  end

  def save_report_account_count
    @save_report_account_count ||= Account.current.report_filters.count
  end

  def scheduled_report_user_count
    @schedule_report_user_count ||= User.current.scheduled_tasks.active_tasks.count
  end

  def scheduled_report_account_count
    @schedule_report_account_count ||= Account.current.scheduled_tasks.active_tasks.count
  end

end
