class ReportsController < ApplicationController

  include ReadsToSlave

  before_filter :disabled_old_reports?
  before_filter :check_old_reports_visibility, :only => [:old, :show]
  before_filter :report_list,:set_selected_tab, :only => [ :index, :show, :old ]
  track_account_setup :index

  include Reports::ConstructReport
  include Reports::ReportTimes
  include HelpdeskReports::Helper::PlanConstraints
  # include Reports::ActivityReport

  helper_method :enable_new_ticket_recieved_metric?

  def show
    @current_report  = @t_reports[params[:report_type].to_sym]
    unless @current_report.nil?
   	  @current_object  = current_account.safe_send(@current_report[:object])
      @report_data     = build_tkts_hash(@current_report[:name],params)
    else
      redirect_to :action => "index"
    end
  end

  def index
    scope = Agent::PERMISSION_TOKENS_BY_KEY[User.current.agent.ticket_permission]
    case scope
    when :all_tickets
      @account_groups = Account.current.groups_from_cache.collect { |g| [g.id, g.name]}
    when :group_tickets, :assigned_tickets
      @account_groups = User.current.agent.agent_groups.collect { |g| [g.group.id, g.group.name]}
    end
    @account_products = Account.current.products.any? ? Account.current.products.collect {|p| [p.id, p.name]} : []
    @date_lag_by_plan = disable_date_lag? ? 0 : 1
    @is_trial_account = Account.current.subscription.trial?
    @hide_agent_metrics_feature = Account.current.euc_hide_agent_metrics_enabled?
  end

  def enable_new_ticket_recieved_metric?
    Account.current.new_ticket_recieved_metric_enabled?
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

  def disabled_old_reports?
    render_404 if current_account.disable_old_reports_enabled?
  end
end
