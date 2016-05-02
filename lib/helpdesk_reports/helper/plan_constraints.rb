module HelpdeskReports::Helper::PlanConstraints

  attr_accessor :plan_group

  PLAN_GROUP_MAPPING = ReportsAppConfig::REPORT_CONSTRAINTS[:plan_groups].inject({}) do 
                        |h,(k,v)| v.each{ |i| h[i] = k }; h
                       end

  FEATURE_BASE_PLAN = {
    :enterprise_reporting => ['estate', 'forest']
  }

  def plan_group
    return @plan_group if defined?(@plan_group)
    account_plan = Account.current.subscription.plan_name
    @plan_group ||= PLAN_GROUP_MAPPING[account_plan] || :default
    if enterprise_reporting? && FEATURE_BASE_PLAN[:enterprise_reporting].exclude?(plan_group)
      @plan_group = FEATURE_BASE_PLAN[:enterprise_reporting].first
    end
    @plan_group
  end
  
  ReportsAppConfig::REPORT_CONSTRAINTS[:plan_constraints].each do |constraint, plans| 
    define_method("#{constraint}?") do
      Account.current.active? && (plans || []).include?(plan_group)
    end
  end

  def enterprise_reporting?
    return @ent_reports_addon if defined?(@ent_reports_addon)
    @ent_reports_addon ||= Account.current.features_included?(:enterprise_reporting)
  end

  def exclude_filters(report_type)  
    excluded_filters = []
    excluded_filters |= ReportsAppConfig::REPORT_CONSTRAINTS[:global_exclude_filters][report_type] || []
    plan_excludes = ReportsAppConfig::REPORT_CONSTRAINTS[:plan_exclude_filters][report_type]
    excluded_filters |= plan_excludes ? plan_excludes[plan_group] : [] 
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
      current_count = send(custom_count_method) if current_count.blank? && defined?(custom_count_method)
    end
    exceeded = (current_count >= limit) if (limit && current_count).is_a? Fixnum
    exceeded
  end

  def max_limit(feature, context)
    feature_limits = ReportsAppConfig::REPORT_CONSTRAINTS[:max_limits][feature] || {}
    limit = (feature_limits[context] || {})
    limit[plan_group] || limit[:default]
  end

  def save_report_user_count
    @save_report_user_count ||= User.current.report_filters.count
  end

  def save_report_account_count
    @save_report_account_count ||= Account.current.report_filters.count
  end

  def scheduled_report_user_count
    @schedule_report_user_count ||= User.current.scheduled_tasks.count
  end

  def scheduled_report_account_count
    @schedule_report_account_count ||= Account.current.scheduled_tasks.count
  end

end