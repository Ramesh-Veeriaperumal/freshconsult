class HelpdeskReports::ParamConstructor::Timespent < HelpdeskReports::ParamConstructor::Base
  
  def initialize(options)
    @report_type = :timespent
    super
  end

  def build_params
    params = {}
    opt = options[:scheduled] ? @export_params : options
    params.merge!(opt)
    params[:filter] ||= []
    if params[:filter].present?
      params[:atleast_once_filter], params[:filter] = params[:filter].partition {|filter_hash| filter_hash[:operator] == "atleast_once_in"}
      params[:drill_down_filter], params[:filter] = params[:filter].partition{|filter_hash| filter_hash[:drill_down_filter]}
      params[:atleast_once_filter] = modify_atleast_once_filter(params[:atleast_once_filter]) if params[:atleast_once_filter].present?
      params.merge!(add_to_std_filter(params,:drill_down_filter,:filter)) if params[:drill_down_filter].present?
    end
    params.merge!(add_to_std_filter(params,:list_conditions, :filter)) if params[:list_conditions].present?
    params[:filter] = modify_filter(params[:filter]) if params[:filter].present?
    params.merge!(export_info(params)) if params[:export]
    params
  end

  def add_to_std_filter(params, from_filter, std_filter)
    params[std_filter].reject!{|filter_hash| filter_hash[:condition] == params[:group_by].first}
    params[std_filter].push(params[from_filter].select{|f_h| f_h[:condition]== params[:group_by].first}.first)
    params[from_filter].reject!{|filter_hash| filter_hash[:condition]==params[:group_by].first}
    {from_filter => params[from_filter], std_filter => params[std_filter]}
  end

  def modify_filter(filter_arr)
    filter_arr.reject!{|f_h| (f_h[:condition]=='is_escalated') && (f_h[:value].split(",").count > 1)}
    filter_arr.each { |f_h| f_h[:operator] = 'is' if f_h[:condition]=='is_escalated' }
    filter_arr
  end

  def modify_atleast_once_filter(atleast_once_filter_arr=[])
    atleast_once_filter_arr.each{|f_h| f_h[:condition].slice!('atleast_once_in_')}
    atleast_once_filter_arr
  end

  def export_info params
    if params[:export_type]=='aggregate_export'
      { details: {l1: params[:group_by].first, l2: ( (params[:group_by].first=='group_id') ? 'agent_id' : 'group_id') } }
    elsif params[:list_conditions].present?
      status = params[:list_conditions].collect{|h| h[:value] if h[:condition]=='status'}.compact.first
      {details: {status_value: status}}
    else
      {}
    end
  end

  def build_export_params
    options[:scheduled] = true
    @export_params = basic_param_structure
    @export_params[:model]  = 'TICKET_LIFECYCLE'
    @export_params[:metric] = 'LIFECYCLE_GROUPBY'
    @export_params[:export] = true
    @export_params[:filter] = @export_params[:filter].map{|f_h| f_h.with_indifferent_access}
    @export_params[:export_type] = 'aggregate_export'
    @export_params[:group_by] = [options[:active_timespent_group_by]]
    params = {} 
    params[:date_range] = date_range
    params[:filter_name] = options[:filter_name]
    params[:report_type] = :timespent
    params[:export_fields] = options[:export_fields]
    params[:export_fields].merge!('group_id' => 'Group', 'agent_id' => 'Agent')
    params[:query_hash] = build_params
    params[:account_id] = Account.current.id
    params[:user_id] = User.current.id
    params[:records_limit] = HelpdeskReports::Constants::Export::FILE_ROW_LIMITS[:export][:csv]
    params
  end
  
end