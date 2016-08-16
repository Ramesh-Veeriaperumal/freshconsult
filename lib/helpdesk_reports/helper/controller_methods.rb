module HelpdeskReports::Helper::ControllerMethods

  include HelpdeskReports::Constants::Common
  include HelpdeskReports::Helper::PlanConstraints

  def report_filter_data_hash
    rep_filters = pre_load_report_filters_with_schedule
    rep_filters.each do |rep_filter|
    	rep_filter[:data_hash]["schedule_config"] = schedule_config_json(rep_filter)
    end
    @report_filter_data = rep_filters
  end

  def pre_load_report_filters_with_schedule
    rt_id = REPORT_TYPE_TO_ENUM[report_type]
  	current_user.report_filters.includes(
  		:scheduled_task => [:schedule_configurations]).by_report_type(rt_id)
  end

  def schedule_config_json report_filter
  	st = report_filter.scheduled_task
  	return {enabled: false} unless st
  	sch_conf = st.schedule_configurations.first.as_json
  	st.as_json({}, false).merge!(sch_conf)
  end

  def common_save_reports_filter
    report_filter = current_user.report_filters.build(
      :report_type => @report_type_id,
      :filter_name => @filter_name,
      :data_hash   => @data_map
    )
    process_reports_filter report_filter
  end

  def common_update_reports_filter
    id = params[:id].to_i
    report_filter = current_user.report_filters.find(id)
    report_filter.assign_attributes(
      :report_type => @report_type_id,
      :filter_name => @filter_name,
      :data_hash   => @data_map
    )
    process_reports_filter report_filter
  end

  def common_delete_reports_filter
    id = params[:id].to_i
    report_filter = current_user.report_filters.find(id)
    report_filter.destroy 
    render json: "success", status: :ok
  end

  def process_reports_filter(report_filter)
    result, status = save_report report_filter
    if @schedule.present?
      if @schedule[:enabled]
        @data_map[:schedule_config] = {enabled: true}
        result = save_scheduled_report report_filter
        status = result.delete(:status)
      else 
        delete_scheduled_report(report_filter)
      end
    end
    render :json => result.to_json, status: status
  end

  def save_report(report_filter)
    report_filter.data_hash['active_custom_field'] = params[:active_custom_field] if params[:active_custom_field]
    if(report_filter.save)
      @data_map[:schedule_config] = {enabled: false}
      status = 200
      res = {:id => report_filter.id,:filter_name=> @filter_name,:data=> @data_map }
    else
      status = 422
      res = {:errors => error_messages(report_filter.errors.messages)}
    end
    [res, status]
  end

  def construct_report_filters
  # @Arun: revisit (Not being used for schedule_config data)
    @data_map = {}
    unless params[:data_hash].blank?
      params[:data_hash].each do |key, value|
        @data_map[escape_keys(key)] = escape_keys(value)
      end
    end
    @schedule = @data_map['schedule_config'].symbolize_keys
    @data_map.delete('schedule_config')
    @report_type_id = REPORT_TYPE_TO_ENUM[report_type.to_sym]
    @filter_name = CGI.escapeHTML(params[:filter_name])
  end

  def escape_keys(value)
    case
    when value.is_a?(Array)
      value.map { |obj| escape_keys(obj) }
    when value.is_a?(Hash)
      value.inject({}) { |h,(k,v)| h[escape_keys(k)] = escape_keys(v); h }
    when !!value == value || value.is_a?(Numeric) #handling boolean case & number
      value
    when value.nil?
      nil
    else
      unescaped_value = CGI::unescapeHTML(value.to_s) #To avoid recursive escaping!
      CGI::escapeHTML(unescaped_value)
    end
  end

  def unescape_keys(value)
    case
    when value.is_a?(Array)
      value.map { |obj| unescape_keys(obj) }
    when value.is_a?(Hash)
      value.inject({}) { |h,(k,v)| h[unescape_keys(k)] = unescape_keys(v); h }
    when !!value == value || value.is_a?(Numeric) #handling boolean case & number
      value
    else
      CGI::unescapeHTML(value.to_s)
    end
  end

  def save_report_max_limit?
    render json: {errors: I18n.t('helpdesk_reports.saved_report.limit_exceeded_message',{count: max_limit(:save_report, :user)})}, status: :unprocessable_entity if max_limits_by_user?(:save_report)
  end

  def get_chat_table_headers
    { 
      :agent_name      => I18n.t('reports.livechat.agent'),
      :answered_chats  => I18n.t('reports.livechat.answered_chats'),
      :avg_handle_time => I18n.t('reports.livechat.avg_handle_time'),
      :total_duration  => I18n.t('reports.livechat.total_duration')
    }
  end
  
end