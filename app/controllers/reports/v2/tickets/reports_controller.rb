class Reports::V2::Tickets::ReportsController < ApplicationController

  include HelpdeskReports::Helper::Ticket
  include ApplicationHelper
  include ExportCsvUtil
  include HelpdeskReports::Helper::ControllerMethods
  include HelpdeskReports::Helper::ScheduledReports
  include HelpdeskReports::Helper::QnaInsightsReports
  include HelpdeskReports::Helper::ThresholdApiHelper
  include Cache::Memcache::Reports::ReportsCache
  include Helpdesk::TicketFilterMethods

  before_filter :check_account_state, :ensure_report_type_or_redirect,
    :plan_constraints,                                      :except => [:download_file]
  before_filter :pdf_export_config, :report_filter_data_hash,           :only   => [:index, :fetch_metrics]
  before_filter :filter_data, :set_selected_tab,                        :only   => [:index, :export_report, :email_reports]
  before_filter :transform_qna_insight_request,                         :only   => [:fetch_qna_metric, :fetch_insights_metric]
  before_filter :transform_threshold_request,                           :only   => [:fetch_threshold_value]
  before_filter :normalize_params, :construct_params, :validate_params, :validate_scope,
    :only_ajax_request, :redirect_if_invalid_request,          :except => [:index, :configure_export, :export_report, :download_file,
                                                                           :save_reports_filter, :delete_reports_filter, :save_insights_config, :fetch_recent_questions]
    before_filter :pdf_params,                                            :only   => [:export_report]
  before_filter :save_report_max_limit?,                                :only   => [:save_reports_filter]
  before_filter :construct_report_filters, :schedule_allowed?,          :only   => [:save_reports_filter,:update_reports_filter]
  before_filter :check_exports_count,                                   :only   => [:export_tickets]
  


  helper_method :enable_schedule_report?, :enable_new_ticket_recieved_metric? 
  wrap_parameters false

  attr_accessor :report_type

  def index
  end

  def fetch_metrics
    generate_data
    render_charts
  end

  def fetch_ticket_list
    generate_data
    send_json_result
  end

  # Action to fetch active metric with all group by in glance report. Separate action to send
  # result as json and avoid rendering view on each new request (user changing active metric).
  def fetch_active_metric
    generate_data
    send_json_result
  end

  def configure_export
    respond_to do |format|
      format.json do
        render :json => report_export_fields
      end
    end
  end

  def export_tickets
    @export_query_params = params[:export_params]
    @query_params = [@export_query_params.delete(:query_hash)]
    construct_params
    validate_scope
    request_object = HelpdeskReports::Request::Ticket.new(@query_params[0], report_type)
    request_object.build_request
    @export_query_params[:user_id]     = current_user.id
    @export_query_params[:account_id]  = current_account.id
    @export_query_params[:report_type] = report_type
    @export_query_params[:portal_url]  = main_portal? ? current_account.host : current_portal.portal_url
    @export_query_params[:query_hash]  = request_object.fetch_req_params
    @export_query_params[:records_limit] = HelpdeskReports::Constants::Export::FILE_ROW_LIMITS[:export][:csv]
    puts (@export_query_params.inspect)

    if generate_data_exports_id
      status_code = :ok
      $sqs_reports_service_export.send_message(@export_query_params.to_json)
    else
      status_code = :unprocessable_entity
    end

    render json: nil, status: status_code
  end

  def export_report
    if [:agent_summary, :group_summary].include?(report_type)
      export_report_csv
    else
      generate_pdf
    end
  end

  def email_reports
    param_constructor = "HelpdeskReports::ParamConstructor::#{report_type.to_s.camelcase}".constantize.new(params.symbolize_keys)
    req_params = param_constructor.build_export_params
    req_params[:portal_name] = current_portal.name if current_portal
    Reports::Export.perform_async(req_params)
    render json: nil, status: :ok
  end

  def save_reports_filter
    common_save_reports_filter
  end

  def update_reports_filter
    common_update_reports_filter
  end

  def delete_reports_filter
    common_delete_reports_filter
  end

  def download_file
    path = "data/helpdesk/#{params[:report_export]}/#{params[:type]}/#{Rails.env}/#{current_user.id}/#{params[:date]}/#{params[:file_name]}.#{params[:format]}"
    redir_url = AwsWrapper::S3Object.url_for(path,S3_CONFIG[:bucket], :expires => 300.seconds, :secure => true)
    redirect_to redir_url
  end
  ############## QnA and Insights Metric Start ########################
  def fetch_qna_metric
    sanitize_qna_metric
    save_recent_question(params[:question])
    generate_data
    @data[:last_dump_time]  = @last_dump_time
    send_json_result
  end

  def sanitize_qna_metric
    params[:question][:text] = h(params[:question][:text])
  end

  def fetch_insights_metric
    key = get_key_for_insights(@query_params)
    cache_data = MemcacheKeys.get_from_cache(key)
    if cache_data.nil?
      generate_data
      @data[:last_dump_time]  = @last_dump_time
      timeout = get_cache_interval_from_synctime(@last_dump_time)
      MemcacheKeys.cache(key, @data, timeout) if @data[:error].nil?
    else
      @data = cache_data
    end
    send_json_result
  end

  def save_insights_config
    save_insights_config_model
    render json: {config: get_insights_widget_config }
  end

  def fetch_recent_questions
    recent_qs = current_user.qna_insight ? current_user.qna_insight.get_recent_questions : []
    render json: { recent_questions: recent_qs }
  end

  def fetch_insights_config
    render json: {config: get_insights_widget_config(params[:widget_type]) }
  end
  ############## QnA and Insights Metric End ########################


  def fetch_threshold_value
    render json: get_threshold
  end


  private

  def generate_data
    build_and_execute
    parse_result
    format_result
  end

  def render_charts
    render :partial => "/reports/v2/tickets/reports/#{report_type}/charts"
  end

  def ensure_report_type_or_redirect
    @report_type = params[:report_type].to_sym if params[:report_type]
    redirect_to reports_path unless LIST_REPORT_TYPES.include?(report_type) && has_scope?(report_type)
  end

  def schedule_allowed?
    if params['data_hash']['schedule_config']['enabled'] == true
      allow = enable_schedule_report? && current_user.privilege?(:export_reports)
      render json: nil, status: :ok if allow != true
    end
  end

  def build_and_execute
    requests = []
    @query_params.each_with_index do |param, i|
      request_object = HelpdeskReports::Request::Ticket.new(param.merge!(index: i), report_type)
      request_object.build_request
      requests << request_object
    end
    response = bulk_request(requests, true)
    @results = []
    response.each do |res|
      if res["last_dump_time"]
        @last_dump_time = set_last_dump_time(res["last_dump_time"]).to_i
      else
        index = res["index"].to_i
        param = requests[index].fetch_req_params
        query_type = requests[index].query_type
        @results << HelpdeskReports::Response::Ticket.new(res, param, query_type, report_type, @pdf_export.present?)
      end
    end
  end

  def normalize_params
    @query_params = params[:_json]
  end

  def parse_result
    if ticket_list_query?
      parse_list_result
    else
      @processed_result = {}
      @results.each do |res_obj|
        key = nil
        if res_obj.query_type == :bucket
          key = "#{res_obj.metric}_BUCKET"
        elsif res_obj.report_type == :insights ||  res_obj.report_type == :threshold # for insights same metric will be used more than once
          key = res_obj.result['index']
        else
          key = res_obj.metric
        end
        @processed_result[key] = res_obj.parse_result
      end
    end
  end

  def format_result
    if formatting_required?
      @data = HelpdeskReports::Formatter::Ticket.new(@processed_result, report_specific_constraints(@pdf_export.present?)).format
    else
      @data = @processed_result
    end
  end

  def formatting_required?
    FORMATTING_REQUIRED.include?(report_type) && !ticket_list_query?
  end

  def generate_pdf
    validate_params
    generate_data
    render :pdf => @report_type,
      :layout => "report/v2/#{report_type}_pdf.html",
      :locals => pdf_locals,
      :show_as_html => false, # renders html version if you set true
      :template => 'sections/generate_report_pdf.pdf.erb',
      :page_size => "A3",
      :javascript_delay => 1000
  end

  def export_report_csv
    validate_params
    generate_data
    csv_result = @data.present? ? export_summary_report : t('helpdesk_reports.no_data_to_display_msg')
    send_csv csv_result
  end

  def ticket_list_query?
    @results.first.query_type == :list
  end

  def parse_list_result
    id_list = @results.first.parse_result
    ticket_from_db id_list
  end

  # TODO -> Ticket from Archive
  def ticket_from_db id_list
    additional_details = {}
    ticket_list_columns = "display_id, subject, responder_id, status, priority, requester_id"
    additional_details[:total_time] = id_list[:total_time] if report_type==:timespent
    tickets, archive_tickets = [], []
    Sharding.select_shard_of(current_account.id) do
      Sharding.run_on_slave do
        tkt = current_account.tickets.permissible(current_user).newest(TICKET_LIST_LIMIT)
        archive_tkt = current_account.archive_tickets.permissible(current_user).newest(TICKET_LIST_LIMIT)
        begin
          # tickets = tkt.find_all_by_id(id_list[:non_archive], :select => ticket_list_columns)
          tickets = tkt.where(id: id_list[:ticket_id]).select(ticket_list_columns).to_a
          # archive_tickets = archive_tkt.find_all_by_ticket_id(id_list[:archive], :select => ticket_list_columns)
          archive_tickets = archive_tkt.where(ticket_id: id_list[:ticket_id]).select(ticket_list_columns).to_a if tickets.count < id_list[:ticket_id].count
        rescue Exception => e
          Rails.logger.error "#{current_account.id} - Error occurred in Business Intelligence Reports while fetching tickets. \n#{e.inspect}\n#{e.message}\n#{e.backtrace.join("\n\t")}"
          NewRelic::Agent.notice_error(e,{:description => "#{current_account.id} - Error occurred in Business Intelligence Reports while fetching tickets"})
        end
        @processed_result = tickets_data((tickets + archive_tickets), additional_details)
      end
    end
  end

  def tickets_data(tickets, additional_details={})
    res=[]
    user_data = pre_load_users(tickets.collect{|t| [t.requester_id, t.responder_id]}.flatten.uniq.compact)
    status_hash, priority_hash = field_id_to_name_mapping("status"), field_id_to_name_mapping("priority")
    tickets.each do |t|
      res_hash = {
        :id         => t.display_id,
        :subject    => escape_keys(t.subject),
        :status     => status_hash[t.status],
        :priority   => priority_hash[t.priority],
        :requester  => user_data[:users][t.requester_id],
        :avatar     => user_data[:avatars][t.requester_id],
        :agent      => (t.responder_id and user_data[:users][t.responder_id]) ? user_data[:users][t.responder_id] : "No Agent"
      }
      res_hash[:total_time] = additional_details[:total_time][t.display_id] if report_type==:timespent
      res << res_hash
    end
    res = res.sort_by{|r_h| r_h[:total_time]}.reverse if report_type == :timespent
    res
  end

  def pre_load_users ids
    users = current_account.all_users.where(id: ids).includes(:avatar).to_a # eager loading user avatar
    id_hash = users.collect{ |u| [u.id, u.name]}.to_h
    avatars = users.collect{ |u| [u.id, user_avatar(u)]}.to_h
    {users: id_hash, avatars: avatars}
  end

  def send_json_result
    respond_to do |format|
      format.json do
        render :json => @data
      end
    end
  end

  def only_ajax_request
    redirect_to reports_path unless request.xhr?
  end

  def generate_data_exports_id
    set_time_zone
    latest_data_export = current_user.data_exports.reports_export.last
    if !latest_data_export || (latest_data_export.status == 4 || latest_data_export.updated_at < (Time.now - 30.minutes))
      @data_export = current_account.data_exports.new(
        :source => DataExport::EXPORT_TYPE[:reports],
        :user => current_user,
        :status => DataExport::EXPORT_STATUS[:started]
      )
      @data_export.save
      @export_query_params[:export_id] = @data_export.id

      acc_export = current_user.data_exports.safe_send("reports_export")
      acc_export.first.destroy if acc_export.count >= TICKET_EXPORT_LIMIT
      return true
    else
      return false
    end
  end

  def has_scope?(report_type)
    if (report_type == :agent_summary && hide_agent_reporting?)
      return false
    # elsif plan_based_report?(report_type)
    #   allowed_plan?(report_type)
    elsif enterprise_reporting?
      ENTERPRISE_REPORTS.include?(report_type)
    elsif current_account.advanced_reporting_enabled?
      ADVANCED_REPORTS.include?(report_type)
    else
      DEFAULT_REPORTS.include?(report_type)
    end
  end

  def construct_params
    return unless(report_type == :timespent && @query_params.present?)
    #Currently input to param constructor is hash.
    #hence following the same std for now. Might follow a common input std for all requests in future.
    new_params = []
    @query_params.each do |param_hash|
      new_params << "HelpdeskReports::ParamConstructor::#{'Timespent'.to_s.camelcase}".constantize.new(param_hash.symbolize_keys).build_params
    end
    @query_params = new_params
  end

  def check_exports_count
    if current_account.data_exports.reports_export.current_exports.count >= EXPORT_REPORT_COUNT
        render json: "ACCOUNT_REPORT_EXPORT_VIOLATION", status: :unprocessable_entity
    end
  end
end
