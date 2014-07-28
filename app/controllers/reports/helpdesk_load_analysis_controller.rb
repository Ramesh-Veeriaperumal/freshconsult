class Reports::HelpdeskLoadAnalysisController < ApplicationController

  include ReadsToSlave
  include Reports::HelpdeskAnalysisReport
  include Reports::HelpdeskReportControllerMethods
  
  before_filter { |c| c.requires_feature :enterprise_reporting }
  before_filter :parse_wf_params,:set_selected_tab, :set_time_range,
                :only => [:generate,:generate_pdf,:send_report_email]
  before_filter :filter_data,:set_selected_tab,:saved_reports, :only => [:index]

  def index
    @report_title = t('adv_reports.helpdesk_load_analysis')
  end

  def saved_reports
    @report_filter_data = report_filter_data_hash REPORT_TYPE_BY_KEY[:helpdesk_load_analysis]
    @report_type = REPORT_TYPE_BY_KEY[:helpdesk_load_analysis]
  end

  def generate
    @data_obj = analysis_report_data @sql_condition.join(" AND ")
    @solution_artical_link = REPORT_ARTICAL_LINKS[:helpdesk_load_analysis]
    render :partial => "/reports/helpdesk_load_analysis/load_analysis"
  end

  def generate_pdf
    @data_obj = analysis_report_data @sql_condition.join(" AND ")
    @report_title = "Helpdesk Load Analysis"
    @custom_fields = params[:custom_fields] unless params[:custom_fields].nil?
    render :pdf => @report_title,
        :layout => 'report/load_analysis_pdf.html.erb', # uses views/layouts/pdf.haml
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