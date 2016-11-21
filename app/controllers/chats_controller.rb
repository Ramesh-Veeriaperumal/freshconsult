class ChatsController < ApplicationController

  include ApplicationHelper
  include ChatHelper

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [ :enable, :update_site, :toggle, :trigger]
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


  def create_ticket
    ticket_params = {
                      :source => TicketConstants::SOURCE_KEYS_BY_TOKEN[:chat],
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
      render :json => { :status => "error" }
    end
  end

  def trigger
    event = params[:eventType]
    content = params[:content]
    content = JSON.parse(params[:content], symbolize_names: true) if content.is_a?(String)
    send(event, content)
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
      render :json => { :status=> "error", :message => "Error while downloading export!"}
    end
  end

  private

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
                :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                :note_body_attributes => { :body_html => note }
            )
    @note.save_note
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
    render :json => { :ticket_id=> @note.notable.display_id , :status => status }
  end

  def missed_chat params
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
                      :source => TicketConstants::SOURCE_KEYS_BY_TOKEN[:chat],
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
    status = @ticket.save_ticket
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

end
