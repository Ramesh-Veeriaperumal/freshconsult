module Reports::HelpdeskReportControllerMethods
	
	def parse_wf_params
    @sql_condition = add_filter_conditions(params)
    @report_date = params[:date_range]
    @filter_data = ActiveSupport::JSON.decode params[:selected_filter_data]
  end
  
  def filter_data
    @show_options = show_options(Reports::Constants::DEFAULT_COLUMNS_ORDER, 
      Reports::Constants::DEFAULT_COLUMNS_KEYS_BY_TOKEN, 
      Reports::Constants::DEFAULT_COLUMNS_OPTIONS)
  end

  def set_selected_tab
    @selected_tab = :reports
  end

  def set_default_values
    @show_fields = {}
    current_account.custom_dropdown_fields_from_cache.each do |f|
      @show_fields[ "#{f.flexifield_def_entry.flexifield_name}"] = f.label
    end
    #added for the nested fields helpdesk_activity_reports
    current_account.nested_fields_from_cache.each do |fields|
      @show_fields["#{fields.flexifield_def_entry.flexifield_name}"] = fields.label
    end
  end

  def add_filter_conditions(params)
    params = params.symbolize_keys!
    unless params[:data_hash].blank? 
      action_hash = params[:data_hash]
      action_hash = ActiveSupport::JSON.decode action_hash unless action_hash.kind_of?(Array)
    end
    conditions = []
    action_hash.each do |filter|
      if Reports::Constants::REDSHIFT_COLUMNS.include? filter["condition"]
        conditions.push create_condtion(filter["condition"], 
          filter["value"].split(",")) unless (filter["condition"].blank? || filter["value"].blank?)
      end
    end
    return conditions
  end

  def create_condtion(condition_key,values)
    values = "'" + values.collect! {|v| Mysql.escape_string(v)}.join("','") + "'"
    return " #{condition_key} in (#{values})"
  end

  def report_filter_data_hash(report_type_id)
    r_f = current_account.report_filters.by_report_type report_type_id
    r_f.inject({}) do |r, h|
      r[h[:id]] = {:name => h[:filter_name], :data => h[:data_hash]}
      r
    end
  end

  def fetch_metric_obj
    metrics_arr = params[:metric_selected].split(",")
    @metrics_data = metrics_arr.inject([]) do |r, key|
      r << Reports::Constants::AJAX_TOP_N_ANALYSIS_COLUMNS[key]
      r
    end
  end
end