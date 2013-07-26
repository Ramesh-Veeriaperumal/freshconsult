class Reports::HelpdeskGlanceReportsController < ApplicationController
  
  include ReadsToSlave
  include Reports::HelpdeskGlanceReport
  include Reports::HelpdeskReportControllerMethods
  include Reports::GlanceReportControllerMethods
  
  before_filter { |c| c.requires_feature :advanced_reporting }
  before_filter :parse_wf_params,:set_selected_tab, 
                :only => [:generate,:generate_pdf,:send_report_email,:fetch_activity_ajax,:fetch_metrics]
  before_filter :filter_data,:set_selected_tab,:saved_reports, :only => [:index]
  before_filter :pass_solution_artical_link, :only => [:fetch_activity_ajax,:fetch_metrics]

  def index
    
  end

  def saved_reports
    @report_filter_data = report_filter_data_hash REPORT_TYPE_BY_KEY[:helpdesk_glance]
    @report_type = REPORT_TYPE_BY_KEY[:helpdesk_glance]
  end

  def generate
    glance_report_data
    @report_title = t('adv_reports.helpdesk_at_a_glance')
    render :partial => "/reports/helpdesk_glance_reports/activity_report"
  end

  def generate_pdf
    glance_report_data
    @custom_fields = params[:custom_fields] unless params[:custom_fields].nil?
    @report_title = t('adv_reports.helpdesk_at_a_glance')
    render :pdf => @report_title,
      :layout => 'report/glance_report_pdf.html', # uses views/layouts/pdf.haml
      :show_as_html => params[:debug].present?, # renders html version if you set debug=true in URL
      :template => 'sections/generate_report_pdf.pdf.erb',
      :page_size => "A3"
  end

  def fetch_metrics
    conditions = @sql_condition.join(" AND ")
    @data_obj = helpdesk_activity_query conditions
    @prev_data_obj = helpdesk_activity_query(conditions, true)
    @helptext_for = "helpdesk"
    render :partial => "/reports/helpdesk_glance_reports/glance_report_metric"
  end
  def fetch_activity_ajax
    @activity_data_hash = fetch_activity_reports_by @sql_condition.join(" AND "), params[:reports_by]
    render :partial => "/reports/helpdesk_glance_reports/custom_chart"
  end

  def send_report_email
    # @data_obj = helpdesk_activity_query @sql_condition.empty? ? nil : @sql_condition.join(" AND ")
    # @activity_data_hash = fetch_activity @sql_condition.empty? ? nil : @sql_condition.join(" AND ")
    # pdf = render_to_string( :pdf => 'my_pdf',
    #                         :formats => [:pdf],
    #                         :template => 'sections/generate_report_pdf.pdf.erb',
    #                         :layout => 'report/pdf.html.erb')
    # puts "===pdfclass=#{pdf.class}"
    # Reports::PdfSender.deliver_send_report_pdf(pdf)

  end

  def pass_solution_artical_link
      @solution_artical_link = REPORT_ARTICAL_LINKS[:helpdesk_glance_report]
  end
end