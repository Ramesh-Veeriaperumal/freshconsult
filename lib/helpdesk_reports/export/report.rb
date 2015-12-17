class HelpdeskReports::Export::Report < HelpdeskReports::Export::Base
  include HelpdeskReports::Helper::Ticket
  
  attr_accessor :report_type, :params

  def perform params
    @params = params
    prepare_params
    generate_report_data
    build_and_email_file
  end
  
  def prepare_params
    @query_params = params[:query_hash].each{|k| k.symbolize_keys!}
    @report_type  = params[:report_type]
    @date_range   = @query_params.first[:date_range]
  end
  
  def build_and_email_file
    options = {
        :user => User.current, 
        :domain => params[:portal_url],
        :export_params => params,
        :report_type => report_type,
        :date_range => @date_range
      }
    options.merge!({:filters => params[:select_hash]}) if report_file_format == "csv"
      
    if @data.present?
      file_path = generate_and_upload_file
      file_name = file_path.split("/").last
      
      if @attachment_via_s3
        options.merge!(:export_url => user_download_url(file_name)) # upload file on S3 and send download link
      else 
        options.merge!(file_path: file_path) # Attach file in mail itself
      end
     
      begin
        ReportExportMailer.bi_report_export(options)
      rescue Exception => err
        NewRelic::Agent.notice_error(err)
      ensure
        FileUtils.rm_f(file_path) if File.exist?(file_path)
      end
    else
      ReportExportMailer.no_report_data(options)
    end
  end
  
  def generate_report_data
    build_and_execute
    parse_result
    format_result
  end
  
  def build_and_execute
    @results = []
    @query_params.each do |param|
      request_object = HelpdeskReports::Request::Ticket.new(param)
      request_object.build_request
      response = request_object.request
      result_object = HelpdeskReports::Response::Ticket.new(response, param, 
        request_object.query_type, report_type, true)
      @results << result_object
    end
  end
  
  def parse_result
    @processed_result = {}
    @results.each do |res_obj|
      key = res_obj.query_type == :bucket ? "#{res_obj.metric}_BUCKET" : res_obj.metric
      @processed_result[key] = res_obj.parse_result
    end
  end
  
  def format_result
    if formatting_required?
      @data = HelpdeskReports::Formatter::Ticket.new(@processed_result, report_specific_constraints).format
    else
      @data = @processed_result
    end
  end
  
  def formatting_required?
    FORMATTING_REQUIRED.include?(report_type.to_sym)
  end
  
  def generate_and_upload_file
    file_format = report_file_format
    file = file_format == "csv" ? export_summary_report : build_pdf
    build_file(file, file_format)
  end
  
  def build_pdf
    trend = params[:trend].symbolize_keys
      
    av = ActionView::Base.new()
    av.view_paths = ActionController::Base.view_paths
    av.view_paths << "app/views"
    
    av.class_eval do
      include ApplicationHelper
      include HelpdeskV2ReportsHelper
    end

    pdf_html = av.render :layout => "layouts/report/v2/#{report_type}_pdf.html",
      :template => 'sections/generate_report_pdf.pdf.erb',
      :locals => {
        report_type: report_type,
        data: @data,
        date_range: @date_range,
        date_lag_by_plan: params[:date_lag_by_plan],
        show_options: params[:show_options],
        label_hash: params[:label_hash],
        nf_hash: params[:nf_hash],
        filters: params[:select_hash],
        trend: trend[:trend],
        resolution_trend: trend[:resolution_trend],
        response_trend: trend[:response_trend],
        pdf_cf: pdf_custom_field || "none"
    }
    pdf = WickedPdf.new.pdf_from_string(pdf_html, :pdf => report_type, :page_size => "A3", :javascript_delay => 1000)
  end
end