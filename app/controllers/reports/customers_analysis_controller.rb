class Reports::CustomersAnalysisController < ApplicationController
  
  include ReadsToSlave
  include Reports::TopNAnalysisReport
  include Reports::HelpdeskReportControllerMethods
  
  before_filter { |c| c.requires_feature :enterprise_reporting }
  before_filter :parse_wf_params,:set_selected_tab, :set_time_range,
                :only => [:generate,:generate_pdf,:send_report_email,:fetch_chart_data]
  before_filter :filter_data,:set_selected_tab,:saved_reports, :only => [:index]
  before_filter :fetch_customer_metric_obj, :only=>[:generate_pdf]

  def index
  end

  def saved_reports
    @report_filter_data = report_filter_data_hash REPORT_TYPE_BY_KEY[:customer_analysis]
    @report_type = REPORT_TYPE_BY_KEY[:customer_analysis]
    @selectable_metrics = AJAX_CUSTOMERS_TOP_N_ANALYSIS_COLUMNS
  end

  def generate
    render :text => "You don't have any customers." and return if params[:customer_select_field].blank?
    @report_title = t('adv_reports.customer_top_n_analysis')
    @data_obj = top_n_analysis_data(CUSTOMERS_TOP_N_ANALYSIS_COLUMNS,
      @sql_condition.join(" AND "), 'customer_id', nil)
    render :partial => "/reports/customers_analysis/customers_analysis"
  end

  def fetch_chart_data 
    @data_obj = top_n_analysis_data([AJAX_CUSTOMERS_TOP_N_ANALYSIS_COLUMNS[params[:reports_by]]],
                @sql_condition.join(" AND "), 'customer_id', params[:order])
    @solution_artical_link = REPORT_ARTICAL_LINKS[:customer_top_n_analysis]

    # added below check for- on clicking sort icon in the graph
    unless params[:order].nil?
      respond_to do |format|
        format.html
        format.json { render :json => @data_obj }
      end
    else
      render :partial => "/reports/customers_analysis/customers_analysis"
    end
  end
  
  def generate_pdf
    @report_title = t('adv_reports.customer_top_n_analysis')
    @data_obj = top_n_analysis_data(@metrics_data,
      @sql_condition.join(" AND "), 'customer_id', nil)
    @custom_fields = params[:custom_fields] unless params[:custom_fields].nil?
    render :pdf => @report_title,
      :layout => 'report/customers_analysis_pdf.html.erb', # uses views/layouts/pdf.haml
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

  private
   def fetch_customer_metric_obj
    metrics_arr = params[:metric_selected].split(",")
    @metrics_data = metrics_arr.inject([]) do |r, key|
      r << AJAX_CUSTOMERS_TOP_N_ANALYSIS_COLUMNS[key]
      r
    end
  end
end