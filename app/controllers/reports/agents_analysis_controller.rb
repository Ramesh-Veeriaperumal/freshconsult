class Reports::AgentsAnalysisController < ApplicationController
  
  include ReadsToSlave
  include Reports::TopNAnalysisReport
  include Reports::HelpdeskReportControllerMethods
  
  before_filter { |c| c.requires_feature :enterprise_reporting }
  before_filter :parse_wf_params,:set_selected_tab, :set_time_range,
                :only => [:generate,:generate_pdf,:send_report_email,:fetch_chart_data]
  before_filter :filter_data,:set_selected_tab,:saved_reports, :only => [:index]
  before_filter :fetch_metric_obj, :only=>[:generate_pdf]

  def index

  end

  def saved_reports
    @report_filter_data = report_filter_data_hash REPORT_TYPE_BY_KEY[:agent_analysis]
    @report_type = REPORT_TYPE_BY_KEY[:agent_analysis]
    @selectable_metrics = AJAX_TOP_N_ANALYSIS_COLUMNS
  end

  def generate
    @report_title = t('adv_reports.agent_top_n_analysis')
    @data_obj = top_n_analysis_data(TOP_N_ANALYSIS_COLUMNS,
      @sql_condition.join(" AND "), 'responder_id', nil)
    render :partial => "/reports/agents_analysis/agent_analysis"
  end

  def fetch_chart_data 
    @data_obj = top_n_analysis_data([AJAX_TOP_N_ANALYSIS_COLUMNS[params[:reports_by]]],
                @sql_condition.join(" AND "), 'responder_id', params[:order])
    @solution_artical_link = REPORT_ARTICAL_LINKS[:agent_top_n_analysis]

    # added below check for- on clicking sort icon in the graph
    unless params[:order].nil?
      respond_to do |format|
        format.html
        format.json { render :json => @data_obj }
      end
    else
      render :partial => "/reports/agents_analysis/agent_analysis"
    end
  end
  
  def generate_pdf    
    @report_title = t('adv_reports.agent_top_n_analysis')
    @data_obj = top_n_analysis_data(@metrics_data,
      @sql_condition.join(" AND "), 'responder_id', nil)
    render :pdf => @report_title,
      :layout => 'report/agent_analysis_pdf.html.erb', # uses views/layouts/pdf.haml
      :show_as_html => params[:debug].present?, # renders html version if you set debug=true in URL
      :template => 'sections/generate_report_pdf.pdf.erb'
  end

  def send_report_email
    # @data_obj = helpdesk_activity_query @sql_condition.empty? ? nil : @sql_condition.join(" AND ")
    # @activity_data_hash = fetch_activity @sql_condition.empty? ? nil : @sql_condition.join(" AND ")
    # pdf = render_to_string( :pdf => 'my_pdf',
    #                         :formats => [:pdf],
    #                         :template => 'sections/generate_report_pdf.pdf.erb',
    #                         :layout => 'report/load_analysis_pdf.html.erb')
    # puts "===pdfclass=#{pdf.class}"
    # Reports::PdfSender.deliver_send_report_pdf(pdf)

  end
end