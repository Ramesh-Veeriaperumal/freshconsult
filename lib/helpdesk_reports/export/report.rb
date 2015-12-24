class HelpdeskReports::Export::Report < HelpdeskReports::Export::Base
  include HelpdeskReports::Helper::Ticket
  include HelpdeskReports::Constants::Export

  attr_accessor :file_format

  def perform
    prepare_params
    build_and_email_file
  end

  private
  
    def prepare_params
      @query_params = params[:query_hash].each{|k| k.symbolize_keys!}
      @file_format  = report_file_format
    end

    def build_and_email_file
      begin_rescue do
        generate_report_data
      
        file_path = generate_and_upload_file if @data.present?
        options   = build_options_for_email
        send_email( options, file_path, PDF_EXPORT_TYPE )
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
        request_object = HelpdeskReports::Request::Ticket.new(param, report_type)
        request_object.build_request
        response = request_object.request
        result_object = HelpdeskReports::Response::Ticket.new(response, param, request_object.query_type, report_type, true)
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
      file = file_format == TYPES[:csv] ? export_summary_report : build_pdf
      build_file(file, file_format, PDF_EXPORT_TYPE)
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
        date_range: date_range,
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

    def build_options_for_email
      {:filters => params[:select_hash]} if file_format == "csv"
    end

    def report_file_format
      ["agent_summary", "group_summary"].include?(report_type) ? "csv" : "pdf"
    end
end
