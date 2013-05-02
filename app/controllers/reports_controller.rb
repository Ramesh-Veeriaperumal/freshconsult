class ReportsController < ApplicationController
 
  include ReadsToSlave
  
  before_filter { |c| c.requires_permission :manage_reports }
  before_filter :report_list,:set_selected_tab, :only => [ :index, :show ]

  include Reports::ConstructReport
  include Reports::ActivityReport
  
  def show
    if params[:id]
      @current_report  = @t_reports[params[:id].to_i-1]       
    end
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
    @t_reports = [{ :name => "responder", :label => t('adv_reports.agent_ticket_summary'), :title => "Agent", :object => "agents" }, 
                  { :name => "group"    , :label => t('adv_reports.group_ticket_summary'), :title => "Group", :object => "groups" }
                 ]
  end
  
  def get_current_object
    
  end

  def set_selected_tab
    @selected_tab = :reports
  end
  
end