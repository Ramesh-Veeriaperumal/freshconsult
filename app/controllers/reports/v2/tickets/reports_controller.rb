class Reports::V2::Tickets::ReportsController < ApplicationController

  include HelpdeskReports::Helper::Ticket
  include ApplicationHelper
  
  before_filter { |c| c.requires_feature :bi_reports }
  
  before_filter :filter_data, :set_selected_tab,                        :only   => [:index]
  before_filter :normalize_params, :validate_params, :validate_scope,   :except => [:index]
  before_filter :set_report_type,                                       :only   => [:fetch_metrics]
  skip_before_filter :verify_authenticity_token,                        :except => [:index]
  
  attr_accessor :report_type

  def index
  end

  def fetch_metrics
    build_and_execute
    parse_result
    render_charts
  end

  def fetch_ticket_list
    build_and_execute
    parse_list_result
    render_tickets
  end

  private

  def render_charts
    # Temporary Hack to enable QA to see json result for other reports
    # and render charts for report_type = ticket_volume
    # currently there is single controller for all reports
    # Below piece of code will be deprecated once controllers are split
    ensure_report_type
    if ["ticket_volume"].include? report_type
      @data = @processed_result
      render :partial => "/reports/v2/tickets/reports/#{report_type}/charts"
    else
      send_json_result
    end
  end
    
  # Temporary, will remove after splitting report controllers
  def ensure_report_type
    @report_type = set_report_type
    if !REPORT_TYPE_BY_NAME.include? report_type
      @report_type = "ticket_volume"
    end
  end
  
  def render_tickets
    send_json_result
  end
  
  def set_report_type
    @report_type = @query_params.first[:report_type]
  end

  def build_and_execute
    @results = []
    @query_params.each do |param|
      request_object = HelpdeskReports::Request::Ticket.new(param)
      request_object.build_request
      response = request_object.request
      result_object = HelpdeskReports::Response::Ticket.new(response, param, request_object.query_type)
      @results << result_object
    end
  end

  # TODO: Need to check if the below method is necessary
  def normalize_params
    @query_params = params[:_json]
  end

  def parse_result
    @processed_result = {}
    @results.each do |res_obj|
      key = res_obj.query_type == :bucket ? "#{res_obj.metric}_BUCKET" : res_obj.metric
      @processed_result[key] = res_obj.parse_result
    end
  end

  def parse_list_result
    id_list = @results.first.parse_result
    ticket_from_db id_list
  end

  # TODO -> Ticket from Archive
  def ticket_from_db id_list
    tkt = current_account.tickets.permissible(current_user)
    begin
      tickets = tkt.newest(TICKET_LIST_LIMIT).find_all_by_id(id_list, :select => "display_id, subject, responder_id, status, priority, requester_id")
    rescue
      tickets = []
    end
    @processed_result = tickets_data(tickets)
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
        :agent      => t.responder_id ? user_data[:users][t.responder_id] : "No Agent"
      }
    end
    res
  end
  
  def pre_load_users ids
    users = current_account.users.find(ids, :include => :avatar) # eager loading user avatar
    id_hash = users.collect{ |u| [u.id, u.name]}.to_h
    avatars = users.collect{ |u| [u.id, user_avatar(u)]}.to_h
    {users: id_hash, avatars: avatars}
  end
  
  def send_json_result
    # temporay hack to see json result, will remove later
    respond_to do |format|
      format.json do
        render :json => @processed_result
      end
    end
  end
  
  # def generate_pdf
  #   glance_report_data
  #   @report_title = t('adv_reports.helpdesk_at_a_glance')
  #   render :pdf => @report_title,
  #     :layout => 'report/glance_report_pdf.html', # uses views/layouts/pdf.haml
  #     :show_as_html => params[:debug].present?, # renders html version if you set debug=true in URL
  #     :template => 'sections/generate_report_pdf.pdf.erb',
  #     :page_size => "A3"
  # end


  # def pass_solution_artical_link
  #   @solution_artical_link = REPORT_ARTICAL_LINKS[:helpdesk_glance_report]
  # end
end
