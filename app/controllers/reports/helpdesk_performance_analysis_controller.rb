class Reports::HelpdeskPerformanceAnalysisController < ApplicationController

  include ReadsToSlave  
  include Reports::HelpdeskAnalysisReport
  include Reports::HelpdeskReportControllerMethods
  
  before_filter { |c| c.requires_feature :enterprise_reporting }
  before_filter { |c| c.requires_permission :manage_reports }
  before_filter :parse_wf_params,:set_selected_tab, :set_time_range,
                :only => [:generate,:generate_pdf,:send_report_email]
  before_filter :filter_data,:set_selected_tab, :only => [:index]

  def index
  end

  def generate
    @report_title = "Helpdesk Performance Analysis"
    @data_obj = performance_analysis_data @sql_condition.join(" AND ")
    @solution_artical_link = %(https://support.freshdesk.com/solution/categories/45929/folders/145570/articles/85343-how-to-read-helpdesk-performance-analysis-report)
    render :partial => "/reports/helpdesk_performance_analysis/performance_analysis"
  end

  def generate_pdf
    @report_title = "Helpdesk Performance Analysis"
    @data_obj = performance_analysis_data @sql_condition.join(" AND ")
    @custom_fields = params[:custom_fields] unless params[:custom_fields].nil?
    render :pdf => @report_title,
        :layout => 'report/performance_analysis_pdf.html.erb', # uses views/layouts/pdf.haml
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