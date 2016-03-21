module HelpdeskReports::Helper::Ticket

  include Redis::RedisKeys
  include Redis::ReportsRedis
  include ExportCsvUtil
  include HelpdeskReports::Constants
  include HelpdeskReports::Field::Ticket
  include HelpdeskReports::Util::Ticket

  VALIDATIONS = ["presence_of_params", "validate_inclusion", "validate_bucketing","validate_dates", "validate_time_trend",
                  "validate_max_filters", "validate_max_multi_selects", "validate_group_by"]

  def filter_data
    show_options(DEFAULT_COLUMNS_ORDER, DEFAULT_COLUMNS_KEYS_BY_TOKEN, DEFAULT_COLUMNS_OPTIONS)
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
  
  def report_export_fields
    @csv_headers = export_fields.select{ |field| required_in_reports?(field) }
  end
  
  def required_in_reports? field
    field[:type] == "nested_field" || field[:type] == "custom_dropdown" || TICKET_EXPORT_FIELDS.include?(field[:value])
  end

  def set_selected_tab
    @selected_tab = :reports
  end
  
  def date_lag_constraint
    # Used to restrict date range in UI according to subscription plan
    @account_time_zone = ActiveSupport::TimeZone::MAPPING[Account.current.time_zone]
    @date_lag_by_plan = DATE_LAG_CONSTRAINT[Account.current.subscription.subscription_plan.name] || 1 
  end

  def ensure_ticket_list
    disabled_plans = ReportsAppConfig::DISABLE_TICKET_LIST[report_type] || []
    @enable_ticket_list_by_plan = !disabled_plans.include?(Account.current.subscription.subscription_plan.name)
  end

  def report_specific_constraints pdf_export
    res = {report_type: report_type}

    if ["agent_summary","group_summary"].include?(report_type)
        group_ids, agent_ids = []
        param = @query_params[0]
        param[:filter].each do |f|
          if report_type == "agent_summary" 
            agent_ids = f["value"].split(",") if f["condition"] == "agent_id"
            group_ids = f["value"] == "-1" ? nil : f["value"].split(",").select{|elem| elem != "-1"} if f["condition"] == "group_id"
          else
            group_ids = f["value"].split(",") if f["condition"] == "group_id"
            agent_ids = f["value"] == "-1" ? nil : f["value"].split(",").select{|elem| elem != "-1"} if f["condition"] == "agent_id"
          end
        end
        res.merge!(group_ids: group_ids.map{|grp_id| grp_id.to_i }) if !group_ids.nil?
        res.merge!(agent_ids: agent_ids.map{|agt_id| agt_id.to_i }) if !agent_ids.nil?
    elsif report_type == "glance"
      res.merge!(pdf_export: pdf_export)
    end
    
    res   
  end
  
  def pdf_params
    args = JSON.parse(params[:pdf_args]).symbolize_keys!
    @query_params = args[:query_hash].each{|k| k.symbolize_keys!}
    @custom_fields_group_by = args[:custom_field]
    @date_range = @query_params.first[:date_range] 
    @filters = args[:select_hash]
    @trend = args[:trend].symbolize_keys
    @pdf_export = true
    @pdf_cf = pdf_custom_field || "none" if report_type == "glance"
  end
  
  def pdf_custom_field
    @query_params.first[:group_by].find{|gp_by| gp_by.start_with?("ffs")} if @query_params.first[:group_by].present?
  end
  
  def email_report_params
    @query_params = params[:query_hash]
    validate_scope
    params.merge!({
      account_id: current_account.id,
      user_id: current_user.id,
      portal_url: current_account.host,
      date_lag_by_plan: @date_lag_by_plan,
      query_hash: @query_params
      })
    params.merge!({show_options: @show_options,label_hash: @label_hash,nf_hash: @nf_hash}) if report_type == "glance"
    
  end
  
  def pdf_locals
    locals = {
      report_type: report_type,
      data: @data,
      date_range: @date_range,
      date_lag_by_plan: @date_lag_by_plan,
      show_options: @show_options,
      label_hash: @label_hash,
      nf_hash: @nf_hash,
      filters: @filters,
      pdf_cf: @pdf_cf
    }
    
    case report_type
      when "ticket_volume"
        locals.merge!(trend: @trend[:trend])
      when "performance_distribution"
        locals.merge!(trend: @trend[:trend],resolution_trend: @trend[:resolution_trend],response_trend: @trend[:response_trend])
    end
    locals
  end

  def export_summary_report
    csv_headers = ["#{report_type.split("_").first}_name"] + (@data.first.keys & METRIC_DISPLAY_NAME.keys)
    csv_string = CSVBridge.generate do |csv|
      csv << csv_headers.collect{|i| METRIC_DISPLAY_NAME[i] || i.capitalize.gsub("_", " ") } # CSV Headers
      @data.each do |row|
        res = []
        csv_headers.each { |i| res << (row[i] == NA_PLACEHOLDER_SUMMARY ? nil : presentable_format(row[i], i))}
        csv << res
      end
    end
    csv_string
  end
  
  def send_csv csv
    send_data csv,
            :type => 'text/csv; charset=utf-8; header=present',
            :disposition => "attachment; filename=#{report_type}.csv"
  end

  # VALIDATION of all params before triggering any QUERY
  def validate_params
    error_list = []
    @query_params.each do |param|
      error_list << VALIDATIONS.inject([]) do |errors, func|
        errors << send(func, param)
      end
    end
    error_list = error_list.flatten.uniq.compact.reject(&:blank?)
    if error_list.any?
      Rails.logger.info "INVALID REPORT PARAMS #{error_list}"
      @filter_err = error_list
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
      range         = param[:date_range].split("-")
      start_date    = Date.parse(range.first)
      end_date      = range.length > 1 ? Date.parse(range.second) : start_date 
      allowed_range = (end_date - start_date) < MAX_ALLOWED_DAYS
      if allowed_range
        account_today = Time.now.in_time_zone(Account.current.time_zone).to_date
        if end_date == account_today and @date_lag_by_plan > 0 # Restrict date_range acc to subscription plan
          start_date -= @date_lag_by_plan
          end_date -= @date_lag_by_plan
          param[:date_range] = "#{start_date.strftime("%d %b,%Y")} - #{end_date.strftime("%d %b,%Y")}"
        end
        []
      else
        ["Maximum allowed days limit exceeded"]
      end
    rescue ArgumentError
      ["Invalid Date"]
    end
  end

  def validate_time_trend param
    report_duration = date_range_diff(param[:date_range])
    
    if report_duration.present? && report_type == "ticket_volume"
      allowed_time_trend = param[:time_trend_conditions]
      TIME_TREND.each{ |trend| allowed_time_trend.delete(trend) if report_duration > MAX_DATE_RANGE_FOR_TREND[trend]}
      param[:time_trend_conditions] = allowed_time_trend
    end
    
    (param[:time_trend_conditions] || []).inject([]) do |errors, tt|
      errors << "Invalid time_trend #{tt}" unless TIME_TREND.include?(tt)
      errors
    end
  end
  
  def date_range_diff range
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
        errors << "Multi select 0 for #{filter["condition"]}"
      elsif value_count > MULTI_SELECT_LIMIT
        errors << "Multi select count exceeded for #{filter["condition"]}"
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
      scoped_group_ids.present? ? validate_filter("group_id", scoped_group_ids)
                                : validate_filter("agent_id", [current_user.id])
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
        new_filter = [add_default_filter(filter_type, scoped_values)]
        new_filter.push(param[:filter])
        param[:filter] = new_filter.flatten
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
    column.starts_with?("ff") or TICKET_FIELD_NAMES.include?(column.to_sym)
  end
  
  def pdf_export_config
    @real_time_export = REAL_TIME_REPORTS_EXPORT
  end
  
  def bulk_request req_params
    begin
      url = ReportsAppConfig::TICKET_REPORTS_URL
      response = RestClient.post url, req_params.to_json, :content_type => :json, :accept => :json
      JSON.parse(response.body)
    rescue => e
      [{"errors" => e.inspect}]     
    end   
  end
  
end
