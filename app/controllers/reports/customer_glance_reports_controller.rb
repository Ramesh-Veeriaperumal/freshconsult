class Reports::CustomerGlanceReportsController < ApplicationController
  
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
    @report_filter_data = report_filter_data_hash REPORT_TYPE_BY_KEY[:customer_glance]
    @report_type = REPORT_TYPE_BY_KEY[:customer_glance]
  end

  def generate
    render :text => "You don't have any customers." and return if params[:customer_select_field].blank?
    glance_report_data
    @report_title = t('adv_reports.customer_at_a_glance')
    @agent_name = customer_name
    render :partial => "/reports/helpdesk_glance_reports/activity_report"
  end

  def generate_pdf
    glance_report_data
    @custom_fields = params[:custom_fields] unless params[:custom_fields].nil?
    @report_title = t('adv_reports.customer_at_a_glance')
    @agent_name = customer_name
    render :pdf => "#{@report_title} - #{@agent_name}",
      :layout => 'report/glance_report_pdf.html', # uses views/layouts/pdf.haml
      :show_as_html => params[:debug].present?, # renders html version if you set debug=true in URL
      :template => 'sections/generate_report_pdf.pdf.erb',
      :page_size => "A3"
  end

  def fetch_metrics
    render :text => "You don't have any customers." and return if params[:customer_select_field].blank?
    conditions = @sql_condition.join(" AND ")
    @data_obj = helpdesk_activity_query conditions
    @prev_data_obj = helpdesk_activity_query(conditions, true)
    @helptext_for = "customer"
    render :partial => "/reports/helpdesk_glance_reports/glance_report_metric"
  end
  def fetch_activity_ajax
    render :text => "You don't have any customers." and return if params[:customer_select_field].blank?
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
      @solution_artical_link = %(https://support.freshdesk.com/solution/categories/45929/folders/145570/articles/85336-how-to-read-customer-at-a-glance-report)
  end

  protected
  def customer_name
    unless params[:customer_select_field].blank? 
      action_hash = params[:customer_select_field]
      action_hash = ActiveSupport::JSON.decode action_hash unless action_hash.kind_of?(Array)
    end
    action_hash[0]['name'];
  end
end