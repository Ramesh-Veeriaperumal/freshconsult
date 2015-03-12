module ChatHelper

  include Livechat::Token
  
  def ticket_link_options
    return [  [  "...",  -1],
              [  I18n.t('freshchat.feedback_widget'),  0],
              [  I18n.t('freshchat.new_ticket_page'),  1],
              [  I18n.t('freshchat.custom_link'),      2] ]
  end

  def chat_activated?
    !current_account.subscription.suspended? && feature?(:chat) && current_account.chat_setting.display_id
  end

  def chat_enabled?
    chat_activated? && current_account.chat_setting.active
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

  def encoded_freshchat_setting
    return Base64.strict_encode64(freshchat_setting(current_chat_widget))
  end

  def default_preferences
    return {
      :window_color    => "#777777",
      :window_position => "Bottom Right",
      :window_offset   => "30",
      :minimized_title => t('freshchat.minimized_title'),
      :maximized_title => t('freshchat.maximized_title'),
      :text_place      => t("freshchat.text_placeholder"),
      :welcome_message => t('freshchat.welcome_message'),
      :thank_message   => t('freshchat.thank_message'),
      :wait_message    => t('freshchat.wait_message'),
      :agent_joined_msg=> t('freshchat.agent_joined_msg'),
      :agent_left_msg  => t('freshchat.agent_left_msg'),
      :connecting_msg  => t('freshchat.connecting_msg')
    }.to_json.html_safe
  end

  def default_prechat_fields
    return {
      :name      => { :title => t("freshchat.name"), "show" => "2" },
      :email     => { :title => t("freshchat.mail"), "show" => "2" },
      :phone     => { :title => t("freshchat.phone"), "show" => "0" },
      :textfield => { :title => t("freshchat.textfield"), "show" => "0" },
      :dropdown  => { :title => t("freshchat.dropdown"), "show"=> "0", "options"=> ["list1","list2","list3"]}
    }.to_json.html_safe
  end

  def default_non_avail_message
    return {
      :text                => t('freshchat.non_availability_message'),
      :ticket_link_option  => 0,
      :custom_link_url     => ""
    }.to_json.html_safe
  end

  def default_offline_chat
    return {
      :show      => "0",
      :form      => { :name => t("freshchat.name"), :email => t("freshchat.mail") },
      :messages  => { :minimized    => t("freshchat.offline_minimized_msg"),
                      :maximized    => t("freshchat.offline_maximized_msg"),
                      :thank        => t("freshchat.offline_thank_msg"),
                      :thank_header => t("freshchat.offline_thank_header_msg") }
    }.to_json.html_safe
  end

  def freshchat_setting widget
    freshchat_setting = {
      :widget_site_url => widget.main_widget ? current_account.full_domain : widget.product.portal ? widget.product.portal.portal_url : current_account.full_domain,
      :product_id => widget.product_id,
      :name => widget.main_widget ? current_account.name : widget.product.name,
      :widget_external_id => widget.product_id,
      :widget_id => widget.widget_id,
      :show_on_portal => widget.show_on_portal,
      :portal_login_required => widget.portal_login_required,
      :id => widget.id,
      :main_widget => widget.main_widget,
      :fc_id => widget.chat_setting.display_id,
      :show => ChatSetting::CHAT_CONSTANTS_BY_KEY[:SHOW],
      :required => ChatSetting::CHAT_CONSTANTS_BY_KEY[:REQUIRED],
      :helpdeskname => current_account.helpdesk_name,
      :name_label =>  t("freshchat.name"),
      :mail_label => t("freshchat.mail"),
      :phone_label => t("freshchat.phone"),
      :textfield_label => t("freshchat.textfield"),
      :dropdown_label => t("freshchat.dropdown"),
      :weburl => current_account.full_domain,
      :nodeurl => ChatConfig["communication_url"],
      :debug => ChatConfig["chat_debug"],
      :me => t("freshchat.me"),
      :expiry =>  chat_trial_expiry,
      :environment => Rails.env,
      :default_window_offset => 30,
      :default_maximized_title => t("freshchat.maximized_title"),
      :default_minimized_title => t("freshchat.minimized_title"),
      :default_text_place => t("freshchat.text_placeholder"),
      :default_connecting_msg => t("freshchat.connecting_msg"),
      :default_welcome_message => t("freshchat.welcome_message"),
      :default_wait_message => t("freshchat.wait_message"),
      :default_agent_joined_msg => t("freshchat.agent_joined_msg"),
      :default_agent_left_msg => t("freshchat.agent_left_msg"),
      :default_thank_message => t("freshchat.thank_message"),
      :default_non_availability_message => t("freshchat.non_availability_message"),
      :default_prechat_message => t("freshchat.prechat_message"),
      :agent_transfered_msg => t("freshchat.agent_transfered_msg")
    }
    return freshchat_setting.to_json.html_safe
  end

  def i18n_text
      text = { 
            :portal_name => t("current_portal.portal_name"),
            :title  => t("freshchat.title"),
            :says => t("freshchat.says"),
            :tag_msg => t("freshchat.tag_msg"),
            :transfer_to_agent => t("freshchat.transfer_to_agent"),
            :block => t("freshchat.block"),
            :unblock => t("freshchat.unblock"),
            :visitor => t("freshchat.visitor"),
            :transfer_agent => t("freshchat.transfer_agent"),
            :agent_transfer_msg => t("freshchat.agent_transfer_msg"),
            :transfer => t("freshchat.transfer"),
            :search_agent => t("freshchat.search_agent"),
            :block_visitor => t("freshchat.block_visitor"),
            :visitor_details => t("freshchat.visitor_details"),
            :visitor_block_msg => t("freshchat.visitor_block_msg"),
            :save=> t("freshchat.save"),
            :cancel=> t("freshchat.cancel"),
            :enter_tags=> t("freshchat.enter_tags"),
            :chat_with => t("freshchat.chat_with"),
            :ticket_success_msg => t("freshchat.ticket_success_msg").html_safe,
            :ticket_error_msg => t("freshchat.ticket_error_msg"),
            :in_conversation => t("freshchat.in_conversation"),
            :available_agents => t("freshchat.available_agents"),
            :returning_visitors => t("freshchat.returning_visitors"),
            :website_visitors_msg => t("freshchat.website_visitors_msg"),
            :message_archives => t("freshchat.message_archives"),
            :connection_error_msg => t("freshchat.connection_error_msg"),
            :connection_success_msg => t("freshchat.connection_success_msg"),
            :website_visitors => t("freshchat.website_visitors"),
            :filter_by => t("freshchat.filter_by"),
            :keyword => t("freshchat.keyword"),
            :visitor_location => t("freshchat.visitor_location"),
            :between => t("freshchat.between"),
            :tags => t("freshchat.tags"),
            :agent => t("freshchat.agent"),
            :back => t("freshchat.back"),
            :select_location => t("freshchat.select_location"),
            :new_visitors => t("freshchat.new_visitors"),
            :visitor_disconnect_msg => t("freshchat.visitor_disconnect_msg"),
            :visitor_left_chat_msg => t("freshchat.visitor_left_chat_msg"),
            :agent_transfer_accept_msg => t("freshchat.agent_transfer_accept_msg"),
            :agent_transfer_reject_msg => t("freshchat.agent_transfer_reject_msg"),
            :agent_transfer_missed_msg => t("freshchat.agent_transfer_missed_msg"),
            :chat_inactive_for_10_min => t("freshchat.chat_inactive_for_10_min"),
            :agent_transfer_waiting_msg => t("freshchat.agent_transfer_waiting_msg"),
            :agent_chat_accept_msg => t("freshchat.agent_chat_accept_msg"),
            :close_chat_tooltip => t("freshchat.close_chat_tooltip"),
            :minimise_chat_tooltip => t("freshchat.minimise_chat_tooltip"),
            :settings_chat_tooltip => t("freshchat.settings_chat_tooltip"),
            :visitor_details_tooltip => t("freshchat.visitor_details_tooltip"),
            :agent_chat_placeholder => t("freshchat.agent_chat_placeholder"),
            :last_message => t("freshchat.last_message"),
            :typing_message => t("freshchat.typing_message"),
            :is_typing_header => t("freshchat.is_typing_header"),
            :chat_recent_empty_tip => t("freshchat.chat_recent_empty_tip"),
            :add_agent_to_chat => t("freshchat.add_agent_to_chat"),
            :accept => t("freshchat.accept"),
            :ignore => t("freshchat.ignore"),
            :transfer_msg => t("freshchat.transfer_msg"),
            :unauthorized_attempt_msg => t("freshchat.unauthorized_attempt_msg"),
            :update_success_msg => t("freshchat.update_success_msg"),
            :update_error_msg => t("freshchat.update_error_msg"),
            :recent_messages => t("freshchat.recent_messages"),
            :agents => t("freshchat.agents"),
            :convert_to_ticket => t("freshchat.convert_to_ticket"),
            :create_ticket_tip => t("freshchat.create_ticket_tip"),
            :error => t("freshchat.error"),
            :existing_tkt_option_tip => t("freshchat.existing_tkt_option_tip").html_safe,
            :select_ticket => t("freshchat.select_ticket"),
            :do_not_convert_tkt => t("freshchat.do_not_convert_tkt"),
            :do_not_convert_tkt_info => t('freshchat.do_not_convert_tkt_info'),
            :go_back => t("freshchat.go_back"),
            :id => t("freshchat.id"),
            :subject => t("freshchat.subject"),
            :requested_by => t("freshchat.requested_by"),
            :find_by_id => t("freshchat.find_by_id"),
            :find_by_subject => t("freshchat.find_by_subject"),
            :find_by_requester => t("freshchat.find_by_requester"),
            :info_msg => t("freshchat.info_msg"),
            :join_chat => t("freshchat.join_chat"),
            :chatting_with => t("freshchat.chatting_with"),
            :returning_visitor => t("freshchat.returning_visitor"),
            :new_visitor => t("freshchat.new_visitor"),
            :unknown => t("freshchat.unknown"),
            :no_visitors => t("freshchat.no_visitors"),
            :no_conversation => t("freshchat.no_conversation"),
            :no_return_visitors => t("freshchat.no_return_visitors"),
            :tag_placeholder => t("freshchat.tag_placeholder"),
            :no_visitors_msg => t("freshchat.no_visitors_msg"),
            :options => t("freshchat.options"),
            :edit_visitor_details => t("freshchat.edit_visitor_details"),
            :new_ticket_tip => t("freshchat.new_ticket_tip").html_safe,
            :install_tip => t('freshchat.install_tip').html_safe,
            :nochat => t('freshchat.nochat'),
            :chat_with_archive => t('freshchat.chat_with_archive').html_safe,
            :chat_loadmore => t('freshchat.chat_loadmore'),
            :chat_viewmore => t('freshchat.chat_viewmore'),
            :ticket_subject => t('freshchat.ticket_subject').html_safe,
            :ticket_description => t('freshchat.ticket_description').html_safe,
            :ticket_title => t('freshchat.ticket_title'),
            :requester_name => t('freshchat.requester_name'),
            :requester_email => t('freshchat.requester_email'),
            :note_success => t('freshchat.note_success').html_safe,
            :note_error => t('freshchat.note_error'),
            :view_details => t('freshchat.view_details'),
            :saving => t('freshchat.saving'),
            :begin_chat => t('freshchat.begin_chat'),
            :min_title => t('freshchat.minimized_title'),
            :max_title => t('freshchat.maximized_title'),
            :wel_msg => t('freshchat.welcome_message'),
            :thank_msg => t('freshchat.thank_message'),
            :wait_msg => t('freshchat.wait_message'),
            :typ_msg => t('freshchat.typing_message'),
            :pre_msg => t('freshchat.prechat_message'),
            :settings_save => t('freshchat.chatsettings_save'),
            :transfer_accepted_msg => t('freshchat.transfer_accepted_msg'),
            :transfer_request_timeout_msg => t('freshchat.transfer_request_timeout_msg'),
            :integrate_freshchat_title => t('freshchat.integrate_freshchat_title'),
            :integrate_freshchat_info => t('freshchat.integrate_freshchat_info'),
            :click_to_go_online => t('freshchat.click_to_go_online').html_safe,
            :click_to_go_offline => t('freshchat.click_to_go_offline').html_safe,
            :fetching => t('freshchat.fetching'),
            :loading => t('freshchat.loading'),
            :last_7_days => t('freshchat.last_7_days'),
            :last_30_days => t('freshchat.last_30_days'),
            :last_90_days => t('freshchat.last_90_days'),
            :date_range => t('freshchat.date_range'),
            :agent_joined_msg => t('freshchat.agent_joined_msg'),
            :agent_left_msg => t('freshchat.agent_left_msg'),
            :agent_transfered_msg => t('freshchat.agent_transfered_msg'),
            :connecting_msg => t('freshchat.connecting_msg'),
            :non_availability_message => t('freshchat.non_availability_message'),
            :me => t('freshchat.me'),
            :on => t('freshchat.texton'),
            :off => t('freshchat.textoff'),
            :copy_to_clipboard => t('freshchat.copy_to_clipboard'),
            :copied => t('freshchat.copied'),
            :loading_new_archives => t('freshchat.loading_new_archives'),
            :incoming_chat => t('freshchat.incoming_chat'),
            :text_place => t('freshchat.text_placeholder'),
            :dropdown_info => t('freshchat.dropdown_info'),
            :dropdown_choices => t('freshchat.dropdown_choices'),
            :done => t('freshchat.done'),
            :edit => t('freshchat.edit'),
            :show => t('freshchat.show'),
            :required => t('freshchat.required'),
            :no_matching_agents => t('freshchat.no_matching_agents'),
            :chat_enabled_label => t('freshchat.chat_enabled_label'),
            :chat_disabled_label => t('freshchat.chat_disabled_label'),
            :transfer_limt_exceeded_msg => t('freshchat.transfer_limt_exceeded_msg'),
            :choice_info => t('freshchat.choice_info').html_safe,
            :concurrent_pick_attempt_msg => t('freshchat.concurrent_pick_attempt_msg'),
            :maximum_chat_error => t('freshchat.maximum_chat_error'),
            :name => t("freshchat.name"),
            :email => t("freshchat.mail"),
            :phone => t("freshchat.phone"),
            :textfield => t("freshchat.textfield"),
            :dropdown => t("freshchat.dropdown"),
            :offline_title => t("freshchat.offline_title"),
            :offline_thank_msg => t("freshchat.offline_thank_msg"),
            :offline_thank_header_msg => t("freshchat.offline_thank_header_msg"),
            :missed_chat_info => t("freshchat.missed_chat_info"),
        }
        return text.to_json.html_safe
  end

  def add_style messages
    conversation = ""
    msgclass = "background:rgba(255,255,255,0.5);";
    messages.each do |msg|
      if msg['userId'] && !(msg['userId'].include?'visitor')
        msgclass = "background:rgba(242,242,242,0.3)";
      end
      time = Time.at(msg['createdAt'] / 1000).strftime('%I:%M %p')
      image = msg['photo'] ? msg['photo'] : '/images/fillers/profile_blank_thumb.gif';
      message = '<tr style="vertical-align:top; border-top: 1px solid #eee; ' + msgclass + '">' +
             '<td style="padding:10px; width:50px; border:0"><img src="'+image+'" style="border-radius: 4px; width: 30px; float: left; border: 1px solid #eaeaea; max-width:inherit" alt="" /></td>' + 
             '<td style="padding:10px 0; width: 80%; border:0"><b style="color:#666;">'+msg['name']+'</b><p style="margin:2px 0 0 0; line-height:18px; color:#777;">'+msg['msg']+'</p></td>' +
             '<td style="padding:10px; font-size:10px; color:#aaa; text-align:right; min-width:50px; border:0">'+time+'</td></tr>'
      conversation += message;
    end
    conversation = '<div class="conversation_wrap"><table style="width:100%; font-size:12px; border-spacing:0px; margin:0; border-collapse: collapse; border-right:0; border-bottom:0;">'+conversation+'</table></div>';
    return conversation
  end

end