class ChatsController < ApplicationController

  include ApplicationHelper
  include ChatHelper
  include Helpdesk::Permission::Ticket

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [ :enable, :toggle, :trigger]
  before_filter  :verify_chat_token, :only => [:trigger]
  around_filter  :select_account, :only => [:trigger]
  before_filter  :load_ticket, :only => [:add_note, :missed_chat]

  def index
    if chat_activated?
      widget_values = current_account.chat_widgets.reject{|c| c.widget_id ==nil}.collect {|c| [c.widget_id,(c.product.blank? ? current_account.name : c.product.name)]}
      @selected_tab = :dashboard
      @widgets = Hash[widget_values.map{ |i| [i[0], i[1]] }].to_json.html_safe
      @widgetsSelectOption = widget_values.map{ |i| [i[1], i[0]] }
      @agentsAvailable = current_account.agents_from_cache.collect { |c| [c.user.name, c.user.id] }
      @dateRange = "#{30.days.ago.strftime("%d %b, %Y")} - #{0.days.ago.strftime("%d %b, %Y")}"
      @export_options = [{ i18n: t('export_data.csv'), en: "CSV" }, { i18n: t('export_data.xls'), en: "Excel" }]
      @export_messages = { :success_message  => t('livechat.export_success', email: current_user.email ),
                           :error_message    => t('livechat.export_error'),
                           :range_limit_message => t('livechat.range_limit_message', range: ChatSetting::EXPORT_DATE_LIMIT) }
      @export_date_limit = ChatSetting::EXPORT_DATE_LIMIT
      @time_zone_offset_in_min = (Time.now.in_time_zone(current_account.time_zone).utc_offset)/60
    else
      render_404
    end
  end


  def request_proxy
    action = params[:action]
    agent_id = params[:id].to_i
    method = convert_http_request_symbol_to_string(params[:method])
    #regular agent can update his own availability (not someone else's)
    if action == 'update_availability' && agent_id == current_user.id
      path, request_params = ["agents/#{agent_id}/updateAvailability", params.slice('status')]
      response = livechat_request(action, request_params,
                                  path, method)
      response_body, response_status = handle_livechat_response(response)
      render :json => response_body, status: response_status
    elsif current_user.privilege?(:admin_tasks)
      path, request_params = parse_and_sanitise_admin_proxy_request(action, method, params)
      response = livechat_request(action, request_params,
                                  path, method)

      response_body, response_status = handle_livechat_response(response)
      render :json => response_body, status: response_status
    else
      render :json => { code: :only_admin_can_create_shortcodes, :status => 403 }, status: 403
    end
  end


  alias_method :create_shortcode, :request_proxy
  alias_method :delete_shortcode, :request_proxy
  alias_method :update_shortcode, :request_proxy
  alias_method :update_availability, :request_proxy

  def create_ticket
    if (params[:ticket].present? && params[:ticket][:email].present?)
      return if !check_permissibility(params[:ticket][:email])
    end
    ticket_params = {
                      :source => Helpdesk::Source::CHAT,
                      :email  => params[:ticket][:email],
                      :phone  => params[:ticket][:phone],
                      :subject  => params[:ticket][:subject],
                      :requester_name => params[:ticket][:name],
                      :ticket_body_attributes => { :description_html => params[:ticket][:content], :description => Helpdesk::HTMLSanitizer.plain(params[:ticket][:content].gsub(/(\s{3,})/,"")).gsub(/\n\t/, "\n") },
                      :responder_id => params[:ticket][:agent_id],
                      :created_at => params[:ticket][:chat_created_at],
                      :cc_email => Helpdesk::Ticket.default_cc_hash
                    }
    widget = current_account.chat_widgets.find_by_widget_id(params[:ticket][:widget_id])
    group = current_account.groups.find_by_id(params[:ticket][:group_id]) if params[:ticket][:group_id]
    ticket_params[:product_id] = widget.product.id if widget && widget.product
    ticket_params[:group_id] = group.id if group

    @ticket = current_account.tickets.build(ticket_params)
    
    @ticket.meta_data =  { 
      :referrer => params[:ticket][:meta][:referrer], 
      :user_agent =>params[:ticket][:meta][:user_agent], 
      :ip_address => params[:ticket][:meta][:ip_address],
      :location => params[:ticket][:meta][:location],
      :visitor_os => params[:ticket][:meta][:visitor_os]
    } if params[:ticket][:meta].present?
    
    status = @ticket.save_ticket

    render :json => { :external_id => @ticket.display_id , :status => status }
  end

  def get_groups
    groups = []
    groups.push([ t("livechat.everyone"), 0 ])
    groups.concat(current_account.groups.collect{|c| [c.name, c.id]})
    render :json => {:groups => groups.to_json}
  end

  def add_note
    user_id = current_user.id
    if(@ticket && (@ticket.responder_id == nil || params[:updateAgent] == "true" ))
      unless params[:chatOwnerId].blank?
        @ticket.responder_id = params[:chatOwnerId]
        user_id = params[:chatOwnerId]
      else
        @ticket.responder_id = current_user.id
      end
      @ticket.save_ticket
    end
    status = create_note(user_id, params[:note], current_account.id)
    render :json => { :external_id=> @note.notable.display_id , :status => status }
  end

  def agents
    agents = current_account.agents_from_cache.collect { |c| {:name=>c.user.name, :id=>c.user.id} }.to_json.html_safe
    render :json => { :agents => agents }
  end

  def visitor
    @selected_tab = :dashboard
  end

  def enable
    status = enable_livechat_feature
    #TODO  neil - fix this as well - status code needed
    render :json => { :status => status }
  end

  def toggle
    chat_setting = current_account.chat_setting

    request_params = { :attributes => params[:attributes] }
    response = livechat_request("update_site", request_params, 'sites/'+chat_setting.site_id, 'PUT')
    if response && response[:status] == 200
      chat_setting.update_attributes({:enabled => params[:attributes][:active]})
      render :json => { :status => "success" }
    else
      #TODO  neil - fix this as well - status code needed
      render :json => { :status => "error" }
    end
  end

  def update_site
    chat_setting = current_account.chat_setting
    request_params = { :attributes => params[:attributes] }
    response = livechat_request("update_site", request_params, 'sites/'+chat_setting.site_id, 'PUT')
    if response && response[:status] == 200
      render :json => { :status => "success" }
    else
      #TODO  neil - fix this as well - status code needed
      render :json => { :status => "error" }
    end
  end

  def trigger
    #TODO NxD - add check - only certain predefined events are allowed to pass thru,
    #TODO contd - reject everything else
    event = params[:eventType]
    content = params[:content]
    content = JSON.parse(params[:content], symbolize_names: true) if content.is_a?(String)
    safe_send(event, content)
  end

  def export 
    request_params = {  :account_name    => current_account.name,
                        :account_domain  => "#{current_account.url_protocol}://#{current_account.full_domain}",
                        :agent_name      => current_user.name,
                        :agent_email     => current_user.email,
                        :filters         => params[:filters], 
                        :format          => params[:format],
                        :support_email   => AppConfig['from_email'],
                        :time_zone_offset_in_min=> (Time.now.in_time_zone(current_account.time_zone).utc_offset)/60 }
    response = livechat_request("export", request_params, 'archive/export', 'POST')
    if response && response[:status] == 200
      status = "success"
    else
      status = "error"
    end
    #TODO  neil - fix this as well - status code needed
    render :json => { :status => status}
  end

  def download_export
    request_params = { :exporttoken => params[:token]}
    response = livechat_request("getExportUrl", request_params, 'archive/exportUrl', 'POST')
    if response && response[:status] == 200
      result = JSON.parse(response[:text])['data']
      url = result['url']
      redirect_to url
    else
      #TODO  neil - fix this as well - status code needed
      render :json => { :status=> "error", :message => "Error while downloading export!"}
    end
  end

  private

  def parse_and_sanitise_admin_proxy_request(action, method, params)
    path, request_params =
      if action == 'create_shortcode' && method == 'POST'
        #puts "INFO app/controllers/chats_controller.rb request_proxy create_shortcode"
        ['shortcodes', params.slice('attributes', 'appId', 'userId', 'siteId', 'token')]
      elsif action == 'delete_shortcode' && method == 'DELETE'
        #puts "INFO app/controllers/chats_controller.rb request_proxy action : delete_shortcode params: #{params.inspect}"
        ["shortcodes/#{params[:id]}", {:attributes => {:empty => :empty}}]
      elsif action == 'update_shortcode' && method == 'PUT'
        #puts "INFO app/controllers/chats_controller.rb  request_proxy update_shortcode"
        ["shortcodes/#{params[:id]}", params.slice('attributes', 'appId', 'userId', 'siteId', 'token') ]
      elsif action == 'update_availability' && method == 'PUT'
        #puts "INFO app/controllers/chats_controller.rb request_proxy action: update_availability  params: #{params.inspect}"
        ["agents/#{agent_id}/updateAvailability", params.slice('status')]
      else
        #puts "Catch all else "
        ["none/livechat_invalid_request", {:attributes => {:empty => :empty}}]
      end
    [path, request_params]
  end

  # this function is needed because httparty needs method as string, comes as :post (interned string from Rails router)
  def convert_http_request_symbol_to_string(method)
    case method
      when :post
        'POST'
      when :get
        'GET'
      when :put
        'PUT'
      when :delete
        'DELETE'
      else
        #cause httparty to fail
        'UNKNOWN'
    end
  end

  def handle_livechat_response(response)
    response_body, response_status =
      if response[:status] >= 200 && response[:status] <= 226 # highest 2xx response code as of 2-nov-2017
        response_body = { code: :success, :status => response[:status] }
        json_parse_body = JSON.parse(response[:text])
        response_body.merge!({ data: json_parse_body['data']}) if json_parse_body.has_key?('data')
        [response_body, response[:status]]
      else
        #render :json => { code: :something_went_wrong, :status => response[:status] }, status: response[:status]
        [{ code: :something_went_wrong, :status => response[:status] }, response[:status]]
      end
    [response_body, response_status]
  end

  def select_account(&block)
    render :json => { :status=> "error", :message => "Account ID Not Found!"} if params[:account_id].nil?
    begin
      Sharding.select_shard_of(params[:account_id]) do
        @current_account = Account.find(params[:account_id])
        @current_account.make_current
        yield
        Account.reset_current_account
      end 
    rescue => e
      #TODO  neil - fix this as well - status code needed
      render :json => { :status=> "error", :message => "Something went wrong => "+e }
    end
  end

  def load_ticket
    @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
  end

  def create_note(userId, note, accId)
    @note = @ticket.notes.build(
                :private => false,
                :user_id => userId,
                :account_id => accId,
                :source => current_account.helpdesk_sources.note_source_keys_by_token['note'],
                :note_body_attributes => { :body_html => note }
            )
    if @note.save_note
      return true
    else
      return false
    end
  end


  # *******  livechat trigger events *******

  def recheck_activation params
    chat_setting = current_account.chat_setting
    status = chat_setting.site_id ? true : chat_setting.update_attributes({ :enabled => true, :site_id => params[:site_id]})
    if params[:widget_id] && !current_account.main_chat_widget.widget_id && status
      status = current_account.main_chat_widget.update_attributes({ :widget_id => params[:widget_id]})
    end
    render :json => { :status => status }
  end

  def recheck_widget_activation params
    chat_widget = current_account.chat_widgets.find_by_product_id params[:product_id] if params[:product_id]
    status = chat_widget.widget_id ? true : chat_widget.update_attributes({ :widget_id => params[:widget_id]})
    render :json => { :status => status }
  end

  def chat_note params
    @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
    if params[:messages]
      note = add_style params[:messages]
    end
    status = create_note(@ticket.requester_id, note, current_account.id)
    #TODO nxd missing save failure should be logged to new relic
    #TODO  neil - fix this as well - status code needed
    render :json => { :ticket_id=> @note.notable.display_id , :status => status }
  end

  # NOTE - this is triggered from livechat.
  def missed_chat params
    if (params[:email].present?)
      return if !check_permissibility(params[:email])
    end
    subject = t("livechat.offline_chat_subject", :visitor_name => params[:name],
                  :date => formated_date(Time.now(), {:format => :short_day_with_week, :include_year => true}))
    if params[:type] == "offline"
      desc = t("livechat.offline_chat_content", :visitor_name => params[:name])
    else
      desc = t("livechat.missed_chat_content", :visitor_name => params[:name])
    end
    if params[:messages]
      message = add_style params[:messages]
      desc = desc + "<br>" + message
    end
    ticket_params = {
                      :source => Helpdesk::Source::CHAT,
                      :email  => params[:email],
                      :subject  => subject,
                      :requester_name => params[:name],
                      :ticket_body_attributes => { :description_html => desc },
                      :cc_email => Helpdesk::Ticket.default_cc_hash
                    }
    widget = current_account.chat_widgets.find_by_widget_id(params[:widget_id])
    group = current_account.groups.find_by_id(params[:group_id]) if params[:group_id]
    ticket_params[:product_id] = widget.product.id if widget && widget.product
    ticket_params[:group_id] = group.id if group

    @ticket = current_account.tickets.build(ticket_params)
    #TODO - nxd - missing save failure should be logged to New relic.
    status = @ticket.save_ticket
    #TODO  neil - fix this as well - status code needed - nxd
    render :json => { :external_id=> @ticket.display_id , :status => status }
  end

  def verify_chat_token
    generatedToken = Digest::SHA512.hexdigest("#{ChatConfig['secret_key']}::#{params['site_id']}")
    if(generatedToken != params['token'])
      Rails.logger.error('ChatsController : Authentication Failed - Invalid Token')
      render :json => { :status=> "error", :message => "Authentication Failed"}
      return
    end
  end

  # *******  End of livechat trigger events *******

  def check_permissibility(email)
    if can_create_ticket? email
      return true
    else
      render :json => { status: "error", message: "User email does not belong to a supported domain."}
      return false
    end
  end

end
