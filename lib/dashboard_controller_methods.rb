module DashboardControllerMethods

  def self.included(base)
    base.send :before_filter, :only => [:unresolved_tickets_dashboard, :overdue, :due_today, :unresolved_tickets_workload, :my_performance, :my_performance_summary, :agent_performance, :agent_performance_summary, :group_performance, :group_performance_summary, :admin_glance, :channels_workload, :top_customers_open_tickets, :top_agents_old_tickets]
    base.send :before_filter, :process_filter_params, :only => [:unresolved_tickets_dashboard, :overdue, :due_today, :trend_count, :unresolved_tickets_workload]
    base.send :before_filter, :filter_group_id, :only => [:agent_performance, :agent_performance_summary, :top_agents_old_tickets]
    base.send :before_filter, :check_supervisor_privilege, :only => [:unresolved_tickets_workload, :agent_performance, :agent_performance_summary, :top_agents_old_tickets]
    base.send :before_filter, :check_admin_privilege, :only => [:group_performance, :group_performance_summary, :top_customers_open_tickets, :admin_glance, :channels_workload]
  end

  #This action gives all trend count that are passed in filters
  #Check custom ticket fileter for supported trends in DEFAULT_FILTERS
  #This is for standard dashboard. Not checking feature for this end point.
  def trend_count
    trend_count = Dashboard::TrendCount.new(@es_enabled, @filter_params).fetch_count
    render :json => {:trends => trend_count}.to_json
  end

  def overdue
    overdue_count = Dashboard::Overdue.new(@es_enabled,@filter_params).fetch_count
    render :json => {:overdue => overdue_count}.to_json
  end

  def due_today
    due_today_count = Dashboard::DueToday.new(@es_enabled,@filter_params).fetch_count
    render :json => {:due_today => due_today_count}.to_json
  end

  def process_filter_params
    @filter_params = {}
    @filter_params[:filter_condition] = {:group_id => params[:group_id]} if params[:group_id].present?
    @filter_params[:group_by] = params[:group_by].split(",") if params[:group_by].present?
    @filter_params[:order_by] = params[:order_by] if params[:order_by].present?
    @filter_params[:trends] = params[:trends].split(",") if params[:trends].present?
    @filter_params[:workload] = params[:workload] if params[:workload]
    @widget_name = params[:widget_name].to_sym if params[:widget_name]
    @filter_params[:widget_name] = params[:widget_name] || ""
    @es_enabled = current_account.count_es_enabled?
  end

  def unresolved_tickets_dashboard
    widget_type = Dashboard::UnresolvedTicket::WIDGET_OPTIONS[@widget_name][:method]
    widget_count = Dashboard::UnresolvedTicket.new(@es_enabled,@filter_params).safe_send("fetch_#{widget_type}")
    render :json => {@widget_name.to_sym => widget_count}.to_json
  end

  def unresolved_tickets_workload
     widget_count = Dashboard::UnresolvedTicketWorkload.new(@es_enabled,@filter_params).fetch_aggregation
     render :json => {:workload => widget_count}.to_json
  end

  def survey_info
    widget_count = Dashboard::SurveyWidget.new.fetch_records
    render :json => {:survey => widget_count}.to_json
  end

  def available_agents
    widget_count = Dashboard::AvailableAgents.new.fetch_records
    render :json => {:available_agents => widget_count}.to_json
  end

  def filter_group_id
    return true if params[:group_id].blank?
    if ( (User.current.assigned_ticket_permission || User.current.group_ticket_permission) && !User.current.agent_groups.pluck(:group_id).include?(params[:group_id].to_i) ) 
      params[:group_id] = nil 
    end
  end

  def check_admin_privilege
    redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE) unless User.current.privilege?(:admin_tasks)
  end

  def check_supervisor_privilege
    redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE) unless (User.current.privilege?(:view_reports) || User.current.privilege?(:admin_tasks))
  end

  def my_performance
    result = Dashboard::MyPerformance.new({}).fetch_results
    render :json => {:result => result}.to_json
  end

  def my_performance_summary
    result = Dashboard::MyPerformance.new({}).fetch_results_summary
    render :json => {:result => result}.to_json
  end

  def agent_performance
    result = Dashboard::AgentsPerformance.new(params.permit(:group_id)).fetch_results    
    render :json => {:result => result}.to_json
  end

  def agent_performance_summary
    result = Dashboard::AgentsPerformance.new(params.permit(:group_id)).fetch_results_summary
    render :json => {:result => result}.to_json
  end

  def group_performance
    result = Dashboard::GroupPerformance.new({}).fetch_results
    render :json => {:result => result}.to_json
  end

  def group_performance_summary
    result = Dashboard::GroupPerformance.new({}).fetch_results_summary
    render :json => {:result => result}.to_json
  end

  def admin_glance
    result = Dashboard::AdminTicketsWorkload.new({}).fetch_results
    render :json => {:result => result}.to_json
  end

  def channels_workload
    result = Dashboard::AdminTicketsWorkload.new({}).fetch_results_by_source
    render :json => {:result => result}.to_json
  end

  def top_customers_open_tickets
    result = Dashboard::RedshiftUnresolvedTickets.new({}).fetch_customer_unresolved
    render :json => {:result => result}.to_json
  end

  def top_agents_old_tickets
    result = Dashboard::RedshiftUnresolvedTickets.new(params.permit(:group_id)).fetch_agent_unresolved
    render :json => {:result => result}.to_json
  end

end
