class HelpdeskReports::Export::Report < HelpdeskReports::Export::Base
  include HelpdeskReports::Helper::Ticket
  include HelpdeskReports::Constants::Export


  def perform
    return email_export(nil) if date_range.nil?
    if report_type.to_sym == :timespent && @scheduled_report
      sqs_export
    else 
      file_path = build_export
      email_export file_path
    end
  end

  private
    
    def build_export
      @query_params = params[:query_hash].each{|k| k.symbolize_keys!}
      generate_report_data
      @data.present? ? generate_file : nil
    end

    def sqs_export
      @query_params = [params.delete(:query_hash)]
      validate_scope
      request_object = HelpdeskReports::Request::Ticket.new(@query_params[0], report_type)
      request_object.build_request
      params[:query_hash] = request_object.fetch_req_params
      params[:scheduled_task_id] = @scheduled_report.id
      AwsWrapper::SqsV2.send_message(SQS[:reports_service_export_queue], params.to_json)
    end

    def email_export file_path
      options   = {:filters => params[:select_hash]} if file_format == "csv"
      send_email( options, file_path, PDF_EXPORT_TYPE )
    end

    def locals_option
      trend = params[:trend].symbolize_keys
      {
        report_type: report_type,
        filter_name: filter_name,
        data: @data,
        last_dump_time: @last_dump_time,
        date_range: date_range,
        label_hash: params[:label_hash],
        nf_hash: params[:nf_hash],
        filters: params[:select_hash],
        trend: trend[:trend],
        resolution_trend: trend[:resolution_trend],
        response_trend: trend[:response_trend],
        pdf_cf: pdf_custom_field || "none"
      }
    end

    def generate_report_data
      build_and_execute
      parse_result
      @no_data ? (@data = nil) : format_result
    end

    def build_and_execute
      requests = []
      @query_params.each_with_index do |param, i|
        param.merge!(export: "pdf_export")
        #param[:time_trend_conditions] = modify_time_trend_condition(param) if param[:time_trend] 
        request_object = HelpdeskReports::Request::Ticket.new(param.merge!(index: i),report_type)
        request_object.build_request
        requests << request_object
      end
          
      response = bulk_request requests
      
      @results = []
      response.each do |res|
        if res["last_dump_time"]
          @last_dump_time = set_last_dump_time(res["last_dump_time"],true).strftime('%e %b, %Y %H:%M %p')
        else
          index = res["index"].to_i
          param = requests[index].fetch_req_params
          query_type = requests[index].query_type
          @results << HelpdeskReports::Response::Ticket.new(res, param, query_type, report_type, true) 
        end
      end
    end

    def parse_result
      @processed_result = {}
      @results.each do |res_obj|
        key = res_obj.query_type == :bucket ? "#{res_obj.metric}_BUCKET" : res_obj.metric
        @processed_result[key] = res_obj.parse_result
      end
      #If processed_result is empty, sending no_data template instead of constructing pdf
      if(@processed_result.values.count{|a| a.empty?} == @processed_result.count)
        @no_data = true
      end
    end

    def format_result
      if FORMATTING_REQUIRED.include?(report_type)
        @data = HelpdeskReports::Formatter::Ticket.new(@processed_result, report_specific_constraints(true)).format
      else
        @data = @processed_result
      end
    end

    def generate_file
      @layout = "layouts/report/v2/#{report_type}_pdf.html"
      file = file_format == TYPES[:csv] ? export_summary_report : build_pdf
      build_file(file, file_format, report_type, PDF_EXPORT_TYPE)
    end

    def build_pdf(is_landscape=false)
      av = ActionView::Base.new()
      av.view_paths = ActionController::Base.view_paths
      av.view_paths << "app/views"
      rt = report_type    #instance variable cannot be used in class-eval
      av.class_eval do
        VIEW_HELPER_MAPPING[rt].each do |file|
          include Object.const_get file
        end
      end
      orientation = is_landscape ? 'Landscape' : 'Portrait'
      pdf_html = av.render :layout => @layout,
                           :template => 'sections/generate_report_pdf',
                           :locals => locals_option,
                           :handlers => [:erb],
                           :formats => [:html]

      pdf = WickedPdf.new.pdf_from_string(pdf_html, :pdf => report_type, :page_size => "A3", :javascript_delay => 1000, :orientation => orientation)
    end

    # def modify_time_trend_condition query
    #   new_time_trend = []
    #   trend_key = METRIC_TIME_TREND_SUB_KEY[report_type][query[:metric].downcase.to_sym]
    #   if @scheduled_report
    #     trend = query[:time_trend_conditions].include?(params[:trend][trend_key]) ? params[:trend][trend_key] : query[:time_trend_conditions].first
    #     params[:trend][trend_key] = trend
    #   else
    #     trend = params[:trend][trend_key.to_s]
    #   end
    #   if report_type == :ticket_volume 
    #     new_time_trend = ["h","dow",trend,"y"]  # "h,dow,y" is needed for all time trends.
    #   elsif report_type.to_sym == :performance_distribution
    #     new_time_trend = [trend,"y"]    # "y" is needed for all time trends
    #     new_time_trend<<"doy" if trend=="w"
    #   end
    #   new_time_trend.uniq
    # end

end
