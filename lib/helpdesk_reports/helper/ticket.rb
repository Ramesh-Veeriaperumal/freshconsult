module HelpdeskReports::Helper::Ticket

  include Redis::RedisKeys
  include Redis::ReportsRedis
  include HelpdeskReports::Field::Ticket
  include HelpdeskReports::Constants::Ticket
  include HelpdeskReports::Util::Ticket

  VALIDATIONS = ["presence_of_params", "validate_inclusion", "validate_bucketing","validate_dates", "validate_time_trend",
                  "validate_max_filters", "validate_max_multi_selects", "validate_group_by"]

  def filter_data
    @show_options = show_options(DEFAULT_COLUMNS_ORDER, DEFAULT_COLUMNS_KEYS_BY_TOKEN, DEFAULT_COLUMNS_OPTIONS)
    @label_hash = column_id_label_hash
  end
  
  def column_id_label_hash
    labels = {}
    @show_options.each do|id, field|
      labels[id] = field[:name]
      if field[:nested_fields]
        field[:nested_fields].each{|n_field| labels[n_field[:condition]] = n_field[:name]}
      end
    end
    labels
  end

  def set_selected_tab
    @selected_tab = :reports
  end
  
  def report_specific_constraints
    res = {report_type: report_type}
    case report_type.to_sym
      when :agent_summary
        group_ids = []
        @query_params.each do |param|
          param[:filter].each{ |f| group_ids |= f["value"].split(",") if f["condition"] == "group_id"}
        end
        res.merge!(group_ids: group_ids.map{|grp_id| grp_id.to_i })
      when :group_summary
        user_ids = []
        @query_params.each do |param|
          param[:filter].each{ |f| user_ids |= f["value"].split(",") if f["condition"] == "agent_id"}
        end
        res.merge!(user_ids: user_ids.map{|u_id| u_id.to_i })
    end
    res   
  end

  # VALIDATION of all params before triggering any QUERY
  def validate_params
    error_list = []
    @query_params.each do |param|
      error_list << VALIDATIONS.inject([]) do |errors, func|
        errors << send(func, param)
        errors.flatten
      end
    end
  
    if error_list.map {|e| e if !e.empty? }.any?
      Rails.logger.info "INVALID REPORT PARAMS #{error_list}"
      @processed_result = {"error" => error_list}
      render_charts
    end
  end

  private

  def presence_of_params param
    REQUIRED_PARAMS.inject([]) do |errors, n_p|      
      #blank check for nil values. Extra false check because false.blank? is true
      errors << "#{n_p} absent" if param[n_p].blank? and param[n_p] != false
      errors
    end
  end

  def validate_inclusion param
    param.inject([]) do |errors, (k,v)|
      errors << "#{k} Invalid value #{v}" unless valid?(k, v)
      errors
    end
  end

  def validate_bucketing param
    (param[:bucket_conditions] || []).inject([]) do |errors, bucket|
      if BUCKET_DIMENSIONS_TO_METRIC[bucket.to_sym].blank?
        errors << "Invalid bucket #{bucket}"
      elsif !BUCKET_DIMENSIONS_TO_METRIC[bucket.to_sym].include? param[:metric]
        errors << "Invalid metric #{param[:metric]} for bucket #{bucket}"
      end
      errors
    end
  end
  
  def validate_dates param
    begin
      range = param[:date_range].split("-")
      Date.parse(range.first)
      Date.parse(range.second) if range.length > 1
      []
    rescue ArgumentError
      ["Invalid Date"]
    end
  end

  def validate_time_trend param
    report_duration = date_range(param[:date_range])
    if report_duration.present? && report_type != "performance_distribution"
       TIME_TREND.each{ |trend| (param[:time_trend_conditions]||[]).delete(trend) if report_duration > MAX_DATE_RANGE_FOR_TREND[trend]}
    end
    
    (param[:time_trend_conditions] || []).inject([]) do |errors, tt|
      errors << "Invalid time_trend #{tt}" unless TIME_TREND.include?(tt)
      errors
    end
  end
  
  def date_range range
    begin
      range = range.split("-")
      range.length > 1 ? (Date.parse(range.second) - Date.parse(range.first)).to_i : 1
    rescue ArgumentError
      nil
    end
  end
  
  def valid? key, value
    value = value.upcase if value.class == String
    PARAM_INCLUSION_VALUES[key].present? ? PARAM_INCLUSION_VALUES[key].include?(value) : true
  end
  
  def validate_max_filters param
    # hack begins
    # Temporary code to display proper error message in case of filter limit exceeded
    # TODO -> write errors in classes
    @filter_err = param[:filter].length > TICKET_FILTER_LIMIT ? t('helpdesk_reports.filter_limit_exceeded', count: TICKET_FILTER_LIMIT) : false
    # hack ends
    param[:filter].length > TICKET_FILTER_LIMIT ? ["Filter limit exceeded"] : []
  end
  
  def validate_max_multi_selects param
    (param[:filter] || []).inject([]) do |errors, filter|
      value_count = filter["value"].split(",").length
      if value_count == 0
        errors << "multi select 0 for #{filter["condition"]}"
      elsif value_count > MULTI_SELECT_LIMIT
        errors << "multi select count exceeded for #{filter["condition"]}"
      end
      errors
    end
  end

  # DO NOT ALLOW filters without group if current_user scope is group_ticket
  # DO NOT ALLOW filters without agent = current_user if scope is restricted
  def validate_scope
    scope = Agent::PERMISSION_TOKENS_BY_KEY[current_user.agent.ticket_permission]
    case scope
    when :group_tickets
      scoped_group_ids = current_user.agent.agent_groups.collect(&:group_id)
      validate_filter "group_id", scoped_group_ids
    when :assigned_tickets
      validate_filter "agent_id", [current_user.id]
    end
  end

  def validate_filter filter_type, scoped_values
    @query_params.each do |param|
      if param[:filter].blank?
        param[:filter] = [add_default_filter(filter_type, scoped_values)]
      elsif filter?(param[:filter], filter_type)
        check_permissible_values(param[:filter], filter_type, scoped_values)
      else
        param[:filter] << add_default_filter(filter_type, scoped_values)
      end
    end
  end

  def filter? filters, filter_type
    filters.inject(false) do |result, f|
      result or (f["condition"] == filter_type)
    end
  end

  def check_permissible_values filters, filter_type, scoped_values
    filters.each do |f|
      if f["condition"] == filter_type
        passed_ids  = f["value"].split(",").map!{|id| id.to_i}
        allowed_ids = scoped_values & passed_ids
        f["value"]  = allowed_ids.join(",")
      end
    end
  end

  def add_default_filter filter_type, scoped_values
    {
      "condition" => filter_type,
      "operator"  => "is_in",
      "value"     => scoped_values.join(",")
    }
  end
  
  def validate_group_by param
    param[:group_by] = [] if (param[:bucket] or param[:list] or param[:time_trend])
    (param[:group_by] || []).inject([]) do |errors, column|
      errors << "Invalid group_by #{column}" unless valid_group_by? column
      errors
    end
  end
  
  def valid_group_by? column
    column.starts_with?("ff") or TICEKT_FIELD_NAMES.include?(column.to_sym)
  end

  def explain
    puts JSON.pretty_generate @data
  end

=begin
    def get_cached_filters(report_type)
      begin
        key_args = { :account_id => current_account.id,
                       :user_id => current_user.id,
                       :session_id => request.session_options[:id],
                       :report_type => report_type
                     }
        reports_filters_str = get_tickets_redis_key(REPORT_TICKET_FILTERS % key_args)
        JSON.parse(reports_filters_str) if reports_filters_str
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    end

    def cache_filters_params(report_type)
      filter_params = params.clone
      filter_params.delete(:action)
      filter_params.delete(:controller)
      begin
        set_tickets_redis_key(redis_key(report_type), filter_params.to_json, 86400)
      rescue Exception => e
        NewRelic::Agent.notice_error(e) 
      end
        @cached_filter_data = get_cached_filters
    end

    def redis_key(report_type)
      key_args = { :account_id => current_account.id,
                   :user_id => current_user.id,
                   :session_id => request.session_options[:id],
                   :report_type => report_type
                 }
      REPORT_TICKET_FILTERS % key_args
    end
=end
end
