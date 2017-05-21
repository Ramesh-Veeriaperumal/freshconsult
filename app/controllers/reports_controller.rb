class ReportsController < ApplicationController

  include ReadsToSlave

  before_filter :check_old_reports_visibility, :only => [:old, :show]
  before_filter :report_list,:set_selected_tab, :only => [ :index, :show, :old ]


  include Reports::ConstructReport
  include Reports::ReportTimes
  include HelpdeskReports::Helper::PlanConstraints
  # include Reports::ActivityReport

  helper_method :enable_lifecycle_report?
  
  def show
    @current_report  = @t_reports[params[:report_type].to_sym]       
    unless @current_report.nil?
   	  @current_object  = current_account.send(@current_report[:object])
      @report_data     = build_tkts_hash(@current_report[:name],params)
    else
      redirect_to :action => "index"
    end
  end
 
 protected 
 
  def scoper
    current_account
  end
  
  def report_list
    @t_reports = {
                  agent_summary: { :name => "responder", :label => t('adv_reports.agent_ticket_summary'), :title => "Agent", :object => "agents" }, 
                  group_summary: { :name => "group"    , :label => t('adv_reports.group_ticket_summary'), :title => "Group", :object => "groups" }
                 }
  end
  
  def get_current_object
    
  end

  def set_selected_tab
    @selected_tab = :reports
  end

  def check_old_reports_visibility
    redirect_to reports_path unless current_account.old_reports_enabled?
  end
  
end