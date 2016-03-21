class Reports::V2::Tickets::ReportsController < ApplicationController

  include HelpdeskReports::Helper::Ticket
  include ApplicationHelper
  include ExportCsvUtil
  include HelpdeskV2ReportsHelper
  helper HelpdeskV2ReportsHelper
  
  before_filter :check_account_state, :ensure_report_type_or_redirect, 
                :date_lag_constraint, :ensure_ticket_list,              :except => [:download_file]              
  before_filter :pdf_export_config, :report_filter_data_hash,           :only   => [:index, :fetch_metrics]
  before_filter :filter_data, :set_selected_tab,                        :only   => [:index, :export_report, :email_reports]
  before_filter :normalize_params, :validate_params, :validate_scope, 
                :only_ajax_request,                                     :except => [:index, :configure_export, :export_report, :download_file,
                                                                                    :save_reports_filter, :delete_reports_filter]
  before_filter :pdf_params,                                            :only   => [:export_report]
  before_filter :max_limit?,                                            :only   => [:save_reports_filter]
  before_filter :construct_filters,                                     :only   => [:save_reports_filter,:update_reports_filter]
  
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
    @query_params  = params[:export_params]
    request_object = HelpdeskReports::Request::Ticket.new(@query_params[:query_hash], report_type)
    request_object.build_request
    @query_params[:user_id]     = current_user.id
    @query_params[:account_id]  = current_account.id
    @query_params[:report_type] = report_type
    @query_params[:portal_url]  = main_portal? ? current_account.host : current_portal.portal_url
    @query_params[:query_hash]  = request_object.fetch_req_params
    
    if generate_data_exports_id
      status_code = :ok
      $sqs_reports_service_export.send_message(@query_params.to_json)
    else
      status_code = :unprocessable_entity
    end
    
    render json: nil, status: status_code
  end
  
  def export_report
    if ["agent_summary", "group_summary"].include?(report_type)
      export_report_csv
    else
      generate_pdf
    end
  end
  
  def email_reports
    email_report_params
    HelpdeskReports::Workers::Export.perform_async(params)
    render json: nil, status: :ok
  end

  def save_reports_filter
    report_filter = current_user.report_filters.build(
      :report_type => @report_type_id,
      :filter_name => @filter_name,
      :data_hash   => @data_map
    )
    report_filter.save
    
    render :json => {:text=> "success", 
                     :status=> "ok",
                     :id => report_filter.id,
                     :filter_name=> @filter_name,
                     :data=> @data_map }.to_json
  end

  def update_reports_filter
    id = params[:id].to_i
    report_filter = current_user.report_filters.find(id)
    report_filter.update_attributes(
      :report_type => @report_type_id,
      :filter_name => @filter_name,
      :data_hash   => @data_map
    )
    render :json => {:text=> "success", 
                     :status=> "ok",
                     :id => report_filter.id,
                     :filter_name=> @filter_name,
                     :data=> @data_map }.to_json
  end

  def delete_reports_filter
    id = params[:id].to_i
    report_filter = current_user.report_filters.find(id)
    report_filter.destroy 
    render json: "success", status: :ok
  end

  
  def download_file
    path = "data/helpdesk/#{params[:report_export]}/#{params[:type]}/#{Rails.env}/#{current_user.id}/#{params[:date]}/#{params[:file_name]}.#{params[:format]}"
    redir_url = AwsWrapper::S3Object.url_for(path,S3_CONFIG[:bucket], :expires => 300.seconds, :secure => true)
    redirect_to redir_url
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
    @report_type = params[:report_type]
    redirect_to reports_path unless REPORT_TYPE_BY_NAME.include?(report_type) && has_scope?(report_type)
  end

  def build_and_execute
    requests = []
    @query_params.each_with_index do |param, i|
      request_object = HelpdeskReports::Request::Ticket.new(param.merge!(index: i), report_type)
      request_object.build_request
      requests << request_object
    end
        
    response = bulk_request requests
    
    @results = []
    response.each do |res|
      index = res["index"].to_i
      param = requests[index].fetch_req_params
      query_type = requests[index].query_type
      @results << HelpdeskReports::Response::Ticket.new(res, param, query_type, report_type, @pdf_export.present?)   
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
        key = res_obj.query_type == :bucket ? "#{res_obj.metric}_BUCKET" : res_obj.metric
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
    FORMATTING_REQUIRED.include?(report_type.to_sym) && !ticket_list_query?
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
    ticket_list_columns = "display_id, subject, responder_id, status, priority, requester_id"
    Sharding.select_shard_of(current_account.id) do
      Sharding.run_on_slave do
        tkt = current_account.tickets.permissible(current_user).newest(TICKET_LIST_LIMIT)
        archive_tkt = current_account.archive_tickets.permissible(current_user).newest(TICKET_LIST_LIMIT)
        begin
          tickets = tkt.find_all_by_id(id_list[:non_archive], :select => ticket_list_columns)
          archive_tickets = archive_tkt.find_all_by_id(id_list[:archive], :select => ticket_list_columns)
        rescue Exception => e
          Rails.logger.error "#{current_account.id} - Error occurred in Business Intelligence Reports while fetching tickets. \n#{e.inspect}\n#{e.message}\n#{e.backtrace.join("\n\t")}"
          NewRelic::Agent.notice_error(e,{:description => "#{current_account.id} - Error occurred in Business Intelligence Reports while fetching tickets"}) 
        end
        @processed_result = tickets_data(tickets + archive_tickets)
      end
    end
  end
  
  def tickets_data(tickets)
    res=[]
    user_data = pre_load_users(tickets.collect{|t| [t.requester_id, t.responder_id]}.flatten.uniq.compact)
    status_hash, priority_hash = field_id_to_name_mapping("status"), field_id_to_name_mapping("priority")
    tickets.each do |t|
      res << {
        :id         => t.display_id,
        :subject    => t.subject,
        :status     => status_hash[t.status],
        :priority   => priority_hash[t.priority],
        :requester  => user_data[:users][t.requester_id],
        :avatar     => user_data[:avatars][t.requester_id],
        :agent      => (t.responder_id and user_data[:users][t.responder_id]) ? user_data[:users][t.responder_id] : "No Agent"
      }
    end
    res
  end
  
  def pre_load_users ids
    users = current_account.all_users.find_all_by_id(ids, :include => :avatar) # eager loading user avatar
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
      @query_params[:export_id] = @data_export.id

      acc_export = current_user.data_exports.send("reports_export")
      acc_export.first.destroy if acc_export.count >= TICKET_EXPORT_LIMIT
      return true
    else
      return false
    end
  end

  def has_scope?(report_type)
    if current_account.features_included?(:enterprise_reporting)
      ENTERPRISE_REPORTS.include?(report_type)
    elsif current_account.features_included?(:advanced_reporting)
      ADVANCED_REPORTS.include?(report_type)
    else
      DEFAULT_REPORTS.include?(report_type)
    end 
  end
  
end

