
module LivechatSettingsTestHelper

  #test_setup
  # Account.current.chat_setting = ""



  def chat_settings_pattern
      {
          CURRENT_ACCOUNT: {
              id: Account.current.id,
              name: Account.current.name ,
              product_id: Account.current.portals.first.product ? Account.current.portals.first.product.id : "",
              domain: Account.current.full_domain,
              chat_enabled: Account.current.chat_setting.enabled,
              # current_chat_widget.widget_id - note - this is defined in main_chat_widget
              widget_id: Account.current.main_chat_widget.widget_id,
              chat_routing: Account.current.has_feature?(:chat_routing),
              cobrowsing: Account.current.has_feature?(:cobrowsing)
          },
          CURRENT_USER: {
              id: @agent.id,
              username: @agent.name,
              isAdmin: @agent.privilege?(:admin_tasks),
              email: @agent.email,
              groups: @agent.agent_groups.collect{|g| g.group_id},
              language: @agent.language,
              time_zone_offset: Time.now.in_time_zone(@agent.time_zone).utc_offset,
              falcon_enabled: true
          },
          CHAT_DEBUG: ChatConfig['chat_debug'],
          LIVECHAT_APP_ID: ChatConfig['app_id'],
          SITE_ID: Account.current.chat_setting.site_id,
          CHAT_CONSTANTS:  ChatSetting::CHAT_CONSTANTS_BY_KEY,
          # LIVECHAT_TOKEN: livechat_token(Account.current.chat_setting.site_id, @agent.id),
          LIVECHAT_TOKEN: String,
          ASSET_URL: ChatConfig['asset_url'],
          CS_URL: ChatConfig['communication_url'],
          CHAT_ENV: Rails.env,
          FC_HTTP_ONLY: ChatConfig['http_only'] == 1
      }
      
    
  end
end