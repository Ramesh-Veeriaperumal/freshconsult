module ChatHelper

  include Livechat::Token

  # LIVECHAT_ROUTE_MAPPINGS = [
  #   [ :create_site,   '/sites/create',    Net::HTTP::Post],
  #   [ :update_site,   '/sites/update',    Net::HTTP::Post],
  #   [ :create_widget, '/widgets/create',  Net::HTTP::Post],
  #   [ :update_widget, '/widgets/update',  Net::HTTP::Post],
  #   [ :get_site,      '/sites/get',        Net::HTTP::Get],
  #   [ :get_widget,    '/widget/get',       Net::HTTP::Get],
  # ]

  # REST_URL = Hash[*LIVECHAT_ROUTE_MAPPINGS.map { |i| [i[0], i[1]] }.flatten]
  # HTTP_METHODS = Hash[*LIVECHAT_ROUTE_MAPPINGS.map { |i| [i[0], i[2]] }.flatten]

  LIVECHAT_ROUTE_MAPPINGS = [
    [ 'GET',    Net::HTTP::Get],
    [ 'PUT',    Net::HTTP::Put],
    [ 'POST',   Net::HTTP::Post],
    [ 'DELETE', Net::HTTP::Delete]
  ]
  HTTP_METHODS = Hash[*LIVECHAT_ROUTE_MAPPINGS.map { |i| [i[0], i[1]] }.flatten]

  def chat_activated?
    !current_account.subscription.suspended? && feature?(:chat) && current_account.chat_setting.site_id
  end

  def chat_enabled?
    chat_activated? && current_account.chat_setting.enabled
  end

  def current_chat_widget
    return main_portal? ? current_account.main_chat_widget : current_portal.product.chat_widget
  end

  def portal_chat_enabled?
    if chat_enabled? && current_chat_widget.show_on_portal 
      if logged_in?
        return current_user.customer?
      else
        return !current_chat_widget.portal_login_required
      end
    else
      return false
    end
  end

  def multiple_business_hours?
    feature?(:multiple_business_hours) && 
      current_account.business_calendar.count > 1
  end

  def default_business_hour
    current_account.business_calendar.default.first.id
  end

  def chat_trial_expiry
    subscription = current_account.subscription 
    subscription.trial? ? subscription.next_renewal_at.to_i * 1000 : 0
  end

  def encoded_livechat_setting
    return Base64.strict_encode64(livechat_setting(current_chat_widget))
  end

  def language(product_id)
   return current_account.portals.find_by_product_id(product_id) ? current_account.portals.find_by_product_id(product_id).language : current_portal.language
  end

  def livechat_setting widget
    widget_language = language(widget.product_id) unless widget.main_widget.blank?
    livechat_setting = {
      :widget_site_url => widget.main_widget ? current_account.full_domain : widget.product.portal ? widget.product.portal.portal_url : current_account.full_domain,
      :product_id => widget.product_id,
      :name => widget.main_widget ? current_account.name : widget.product.name,
      :widget_external_id => widget.product_id,
      :widget_id => widget.widget_id,
      :show_on_portal => widget.show_on_portal,
      :portal_login_required => widget.portal_login_required,
      :language => widget.main_widget ? (current_portal ? current_portal.language : I18n.default_locale) : widget_language,
      :timezone => current_account.time_zone,
      :id => widget.id,
      :main_widget => widget.main_widget,
      :fc_id => widget.chat_setting.site_id,
      :show => ChatSetting::CHAT_CONSTANTS_BY_KEY[:SHOW],
      :required => ChatSetting::CHAT_CONSTANTS_BY_KEY[:REQUIRED],
      :helpdeskname => current_account.helpdesk_name,
      :name_label =>  t("livechat.name"),
      :message_label => t("livechat.message"),
      :phone_label => t("livechat.phone"),
      :textfield_label => t("livechat.textfield"),
      :dropdown_label => t("livechat.dropdown"),
      :weburl => current_account.full_domain,
      :nodeurl => ChatConfig["communication_url"],
      :debug => ChatConfig["chat_debug"],
      :me => t("livechat.me"),
      :expiry =>  chat_trial_expiry,
      :environment => Rails.env,
      :end_chat_thank_msg => t('livechat.end_chat_thank_msg'),
      :end_chat_end_title => t('livechat.end_chat_end_title'),
      :end_chat_cancel_title => t('livechat.end_chat_cancel_title')
    }
    return livechat_setting.to_json.html_safe
  end

  def i18n_text
      text = { 
            :portal_name => t("current_portal.portal_name"),
            :title  => t("livechat.title"),
            :says => t("livechat.says"),
            :tag_msg => t("livechat.tag_msg"),
            :transfer_to_agent => t("livechat.transfer_to_agent"),
            :no_agents_available => t("livechat.no_agents_available"),
            :block => t("livechat.block"),
            :unblock => t("livechat.unblock"),
            :visitor => t("livechat.visitor"),
            :transfer_agent => t("livechat.transfer_agent"),
            :transfer => t("livechat.transfer"),
            :search_agent => t("livechat.search_agent"),
            :block_visitor => t("livechat.block_visitor"),
            :visitor_details => t("livechat.visitor_details"),
            :visitor_block_msg => t("livechat.visitor_block_msg"),
            :save=> t("livechat.save"),
            :cancel=> t("livechat.cancel"),
            :enter_tags=> t("livechat.enter_tags"),
            :chat_with => t("livechat.chat_with"),
            :ticket_success_msg => t("livechat.ticket_success_msg").html_safe,
            :ticket_error_msg => t("livechat.ticket_error_msg"),
            :in_conversation => t("livechat.in_conversation"),
            :available_agents => t("livechat.available_agents"),
            :returning_visitors => t("livechat.returning_visitors"),
            :website_visitors_msg => t("livechat.website_visitors_msg"),
            :message_archives => t("livechat.message_archives"),
            :connection_error_msg => t("livechat.connection_error_msg"),
            :connection_success_msg => t("livechat.connection_success_msg"),
            :website_visitors => t("livechat.website_visitors"),
            :filter_by => t("livechat.filter_by"),
            :keyword => t("livechat.keyword"),
            :visitor_location => t("livechat.visitor_location"),
            :between => t("livechat.between"),
            :tags => t("livechat.tags"),
            :agent => t("livechat.agent"),
            :back => t("livechat.back"),
            :select_location => t("livechat.select_location"),
            :new_visitors => t("livechat.new_visitors"),
            :chat_inactive_for_10_min => t("livechat.chat_inactive_for_10_min"),
            :close_chat_tooltip => t("livechat.close_chat_tooltip"),
            :minimise_chat_tooltip => t("livechat.minimise_chat_tooltip"),
            :settings_chat_tooltip => t("livechat.settings_chat_tooltip"),
            :visitor_details_tooltip => t("livechat.visitor_details_tooltip"),
            :agent_chat_placeholder => t("livechat.agent_chat_placeholder"),
            :visitor_block_notifier_msg => t("livechat.visitor_block_notifier_msg"),
            :visitor_unblock_notifier_msg => t("livechat.visitor_unblock_notifier_msg"),
            :last_message => t("livechat.last_message"),
            :typing_message => t("livechat.typing_message"),
            :is_typing_header => t("livechat.is_typing_header"),
            :chat_recent_empty_tip => t("livechat.chat_recent_empty_tip"),
            :add_agent_to_chat => t("livechat.add_agent_to_chat"),
            :accept => t("livechat.accept"),
            :ignore => t("livechat.ignore"),
            :transfer_msg => t("livechat.transfer_msg"),
            :unauthorized_attempt_msg => t("livechat.unauthorized_attempt_msg"),
            :update_success_msg => t("livechat.update_success_msg"),
            :update_error_msg => t("livechat.update_error_msg"),
            :recent_messages => t("livechat.recent_messages"),
            :chat => t("livechat.chat"),
            :view_recent_conversation => t("livechat.view_recent_conversation"),
            :view_all_messages => t("livechat.view_all_messages"),
            :agents => t("livechat.agents"),
            :convert_to_ticket => t("livechat.convert_to_ticket"),
            :create_ticket_tip => t("livechat.create_ticket_tip"),
            :error => t("livechat.error"),
            :existing_tkt_option_tip => t("livechat.existing_tkt_option_tip").html_safe,
            :select_ticket => t("livechat.select_ticket"),
            :do_not_convert_tkt => t("livechat.do_not_convert_tkt"),
            :do_not_convert_tkt_info => t('livechat.do_not_convert_tkt_info'),
            :go_back => t("livechat.go_back"),
            :id => t("livechat.id"),
            :subject => t("livechat.subject"),
            :requested_by => t("livechat.requested_by"),
            :find_by_id => t("livechat.find_by_id"),
            :find_by_subject => t("livechat.find_by_subject"),
            :find_by_requester => t("livechat.find_by_requester"),
            :info_msg => t("livechat.info_msg"),
            :join_chat => t("livechat.join_chat"),
            :chatting_with => t("livechat.chatting_with"),
            :chatted_with => t("livechat.chatted_with"),
            :returning_visitor => t("livechat.returning_visitor"),
            :new_visitor => t("livechat.new_visitor"),
            :unknown => t("livechat.unknown"),
            :no_visitors => t("livechat.no_visitors"),
            :no_conversation => t("livechat.no_conversation"),
            :no_return_visitors => t("livechat.no_return_visitors"),
            :tag_placeholder => t("livechat.tag_placeholder"),
            :no_visitors_msg => t("livechat.no_visitors_msg"),
            :options => t("livechat.options"),
            :edit_visitor_details => t("livechat.edit_visitor_details"),
            :new_ticket_tip => t("livechat.new_ticket_tip").html_safe,
            :install_tip => t('livechat.install_tip').html_safe,
            :nochat => t('livechat.nochat'),
            :chat_with_archive => t('livechat.chat_with_archive').html_safe,
            :chat_loadmore => t('livechat.chat_loadmore'),
            :chat_viewmore => t('livechat.chat_viewmore'),
            :ticket_subject => t('livechat.ticket_subject').html_safe,
            :ticket_description => t('livechat.ticket_description').html_safe,
            :ticket_title => t('livechat.ticket_title'),
            :requester_name => t('livechat.requester_name'),
            :requester_email => t('livechat.requester_email'),
            :note_success => t('livechat.note_success').html_safe,
            :note_error => t('livechat.note_error'),
            :view_details => t('livechat.view_details'),
            :saving => t('livechat.saving'),
            :begin_chat => t('livechat.begin_chat'),
            :typ_msg => t('livechat.typing_message'),
            :pre_msg => t('livechat.prechat_message'),
            :settings_save => t('livechat.chatsettings_save'),
            :integrate_livechat_title => t('livechat.integrate_livechat_title'),
            :integrate_livechat_info => t('livechat.integrate_livechat_info'),
            :click_to_go_online => t('livechat.click_to_go_online').html_safe,
            :click_to_go_offline => t('livechat.click_to_go_offline').html_safe,
            :fetching => t('livechat.fetching'),
            :loading => t('livechat.loading'),
            :last_7_days => t('livechat.last_7_days'),
            :last_30_days => t('livechat.last_30_days'),
            :last_90_days => t('livechat.last_90_days'),
            :date_range => t('livechat.date_range'),
            :me => t('livechat.me'),
            :on => t('livechat.texton'),
            :off => t('livechat.textoff'),
            :copy_to_clipboard => t('livechat.copy_to_clipboard'),
            :copied => t('livechat.copied'),
            :loading_new_archives => t('livechat.loading_new_archives'),
            :incoming_chat => t('livechat.incoming_chat'),
            :dropdown_info => t('livechat.dropdown_info'),
            :dropdown_choices => t('livechat.dropdown_choices'),
            :done => t('livechat.done'),
            :edit => t('livechat.edit'),
            :show => t('livechat.show'),
            :required => t('livechat.required'),
            :no_matching_agents => t('livechat.no_matching_agents'),
            :chat_enabled_label => t('livechat.chat_enabled_label'),
            :chat_disabled_label => t('livechat.chat_disabled_label'),
            :transfer_limt_exceeded_msg => t('livechat.transfer_limt_exceeded_msg'),
            :choice_info => t('livechat.choice_info').html_safe,
            :concurrent_pick_attempt_msg => t('livechat.concurrent_pick_attempt_msg'),
            :maximum_chat_error => t('livechat.maximum_chat_error'),
            :missed_chat_info => t("livechat.missed_chat_info"),
            :shorthands => t('short_code.title'),
            :no_code => t('short_code.no_code'),
            :unmark_spam => t('livechat.unmark_spam'),
            :mark_spam => t('livechat.mark_spam'),
            :convert => t('livechat.convert'),
            :conversation => t('livechat.conversation'),
            :missed_chat => t('livechat.missed_chat'),
            :visitor_initiated_chat => t('livechat.visitor_initiated_chat'),
            :agent_initiated_chat => t('livechat.agent_initiated_chat'),
            :view_chat_link => t('livechat.view_chat_link'),
            :and => t('livechat.and'),
            :via_widget => t('livechat.via_widget'),
            :waited_for => t('livechat.waited_for'),
            :duration => t('livechat.duration'),
            :reported => t('livechat.reported'),
            :add_note => t('livechat.add_note'),
            :view_ticket => t('livechat.view_ticket'),
            :no_agents => t('helpdesk.dashboard.livechat.no_agents'),
            :no_activity => t('helpdesk.dashboard.livechat.no_activity'),
            :last_active => t('helpdesk.dashboard.livechat.last_active'),
            :chats_in_progress => t('helpdesk.dashboard.livechat.chats_in_progress'),
            :cobrowse_request => t('livechat.cobrowse_request'),
            :cobrowsing_start_msg => t('livechat.cobrowsing_start_msg'), 
            :cobrowsing_stop_msg => t('livechat.cobrowsing_stop_msg'),    
            :cobrowsing_deny_msg => t('livechat.cobrowsing_deny_msg'),    
            :cobrowsing_viewing_screen => t('livechat.cobrowsing_viewing_screen'),    
            :cobrowsing_controlling_screen => t('livechat.cobrowsing_controlling_screen'),    
            :cobrowsing_request_control => t('livechat.cobrowsing_request_control'),    
            :cobrowsing_stop_request => t('livechat.cobrowsing_stop_request'),    
            :cobrowsing_request_control_rejected => t('livechat.cobrowsing_request_control_rejected'),
            :agent_parallel_accept_error => t('livechat.agent_parallel_accept_error')
        }
        return text.to_json.html_safe
  end

  def add_style messages
    conversation = ""
    msgclass = "background:rgba(255,255,255,0.5);";
    messages.each do |msg|
      if msg[:userId] && !(msg[:userId].include?'visitor')
        msgclass = "background:rgba(242,242,242,0.3)"
      end
      image = msg[:photo] ? msg[:photo] : '/images/fillers/profile_blank_thumb.gif';
      if msg[:type] != "2"
        message = '<tr style="vertical-align:top; border-top: 1px solid #eee; ' + msgclass + '">' +
               '<td style="padding:10px; width:50px; border:0"><img src="'+image+'" style="border-radius: 4px; width: 30px; float: left; border: 1px solid #eaeaea; max-width:inherit" alt="" /></td>' + 
               '<td style="padding:10px 0; width: 80%; border:0"><b style="color:#666;">'+msg[:name]+'</b><p style="margin:2px 0 0 0; line-height:18px; color:#777;">'+msg[:msg]+'</p></td><td>&nbsp;</td>' 
        conversation += message;   
      end   
    end
    conversation = '<div class="conversation_wrap"><table style="width:100%; font-size:12px; border-spacing:0px; margin:0; border-collapse: collapse; border-right:0; border-bottom:0;">'+conversation+'</table></div>';
    return conversation
  end

  def live_chat_url
    url = "http://" + ChatConfig["communication_url"]
    url = url + ":4000" if Rails.env == "development"
    return url
  end

  def livechat_request(type, params, path, requestType)
    response_code = 200
    content_type  = "application/json"
    accept_type   = "application/json"
    response_type = "application/json"
    begin
      # request_url = live_chat_url + REST_URL[type.to_sym].to_s
      request_url = live_chat_url + "/" + path
      options = Hash.new
      auth_details = { :appId => ChatConfig["app_id"], :userId => current_user.id }
      unless type === "create_site"
        site_id  = current_account.chat_setting.site_id
        auth_details[:siteId] = site_id
        auth_details[:token]   = livechat_token(site_id, current_user.id)
      else
        auth_details[:token]   = livechat_partial_token(current_user.id)
      end
      request_data      = params.merge(auth_details)
      options[:body]    = JSON.generate(request_data)
      options[:headers] = { "Accept" => accept_type, "Content-Type" => content_type}.delete_if{ |k,v| v.blank? }  # TODO: remove delete_if use and find any better way to do it in single line
      options[:timeout] = params[:timeout] || 15 #Returns status code 504 on timeout expiry 
      begin
        # proxy_request  = HTTParty::Request.new(HTTP_METHODS[type.to_sym], request_url, options)
        proxy_request  = HTTParty::Request.new(HTTP_METHODS[requestType], request_url, options)
        proxy_response = proxy_request.perform
        response_body  = proxy_response.body
        response_code  = proxy_response.code
        response_type  = proxy_response.headers['content-type']
      rescue Timeout::Error
        Rails.logger.error("Timeout trying to complete the request. \n#{params.inspect}")
        response_body = '{"result":"timeout"}'
        response_code = 504  # Timeout
      rescue => e
        Rails.logger.error("Error while processing proxy request::: #{e.message}\n#{e.backtrace.join("\n")}")
        response_body = '{"result":"error"}'
        response_code = 502  # Bad Gateway
      end
    rescue => e
      Rails.logger.error("Error while processing proxy request:::: #{params.inspect}. \n#{e.message}\n#{e.backtrace.join("\n")}")
      response_body = '{"result":"error"}'
      response_code = 500  # Internal server error
    end
    response_type = accept_type if response_type.blank?
    begin
      if proxy_response.present? && accept_type == "application/json" && !(response_type.start_with?("application/json") || response_type.start_with?("js"))
        response_body = proxy_response.parsed_response.to_json
        response_type = "application/json"
      end
    rescue => e
     Rails.logger.error("Error while parsing remote response.")
    end
    return { :text=> response_body, :content_type => response_type, :status => response_code }
  end
  
end