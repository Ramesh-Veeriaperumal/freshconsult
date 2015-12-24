module Reports::HelpdeskReportControllerMethods
  include Redis::RedisKeys
  include Redis::ReportsRedis
  
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
    #params = params.symbolize_keys!
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
    values = "'" + values.collect! {|v| mysql_escape(v)}.join("','") + "'"
    return " #{condition_key} in (#{values})"
  end

  def mysql_escape(string)
    Mysql2::Client.escape(string)
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

  def cache_report_filter_params(glance_type)
    filter_params = params.clone.symbolize_keys
    date_range = filter_params[:date_range]
    date_range = [date_range, date_range].join(' - ') if !date_range.include?(' - ')
    filter_params.select! {|k,v| [:data_hash].include?(k) }
    parsed_data_hash = JSON.parse(filter_params[:data_hash])

    # Prepending flexifields and users class to match the condition as in ticket list view data hash
    parsed_data_hash.each do |x|
      x['condition'].prepend('flexifields.') if x['condition'].include?('ffs_')
    end

    Reports::Constants::REPORTS_GLANCE_TICKET_VIEW[glance_type.to_sym].each do |report_type|

      condition_key = TicketConstants::REPORT_TYPE_HASH[report_type]
      filter = [{:condition => condition_key, :operator => :is_greater_than, :value => date_range}]
      filter.push({:condition => :status,
                   :operator => :is_in,
                   :value => "#{Helpdesk::Ticketfields::TicketStatus::RESOLVED},#{Helpdesk::Ticketfields::TicketStatus::CLOSED}"}) if report_type.to_s.include?('resolved')
      filter_params[:data_hash] = (parsed_data_hash | filter).to_json
      filter_params.merge!(:unsaved_view => true)
      begin
        set_reports_redis_key(report_filter_redis_key(report_type), filter_params.to_json, 86400)
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end

    end
  end

  def report_filter_redis_key(report_type)
    key_args = { :account_id => current_account.id,
                 :user_id => current_user.id,
                 :session_id => request.session_options[:id],
                 :report_type => report_type
               }
    REPORT_TICKET_FILTERS % key_args
  end
end
