class HelpdeskReports::ParamConstructor::Timespent < HelpdeskReports::ParamConstructor::Base
  
  def initialize(options)
    @report_type = :timespent
    super
  end

  def build_params
    params = {}
    params.merge!(options)
    params[:filter] ||= []
    if params[:filter].present?
      params[:atleast_once_filter], params[:filter] = params[:filter].partition {|filter_hash| filter_hash[:operator] == "atleast_once_in"}
      params[:drill_down_filter], params[:filter] = params[:filter].partition{|filter_hash| filter_hash[:drill_down_filter]}
      params[:atleast_once_filter] = modify_atleast_once_filter(params[:atleast_once_filter]) if params[:atleast_once_filter].present?
      params.merge!(add_to_std_filter(params,:drill_down_filter,:filter)) if params[:drill_down_filter].present?
    end
    params.merge!(add_to_std_filter(params,:list_conditions, :filter)) if params[:list_conditions].present?
    params[:filter] = modify_filter(params[:filter]) if params[:filter].present?
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
  
end