class ChatSettingDecorator < ApiDecorator
  include Livechat::Token
  def initialize(account, portal, user)
    super(account)
    @portal = portal
    @user = user
    end

  def to_hash
    {
      CURRENT_ACCOUNT: get_current_account,
        CURRENT_USER: get_current_user,
        CHAT_DEBUG: ChatConfig['chat_debug'],
        LIVECHAT_APP_ID: ChatConfig['app_id'],
        SITE_ID: record.chat_setting.site_id,
        CHAT_CONSTANTS:  ChatSetting::CHAT_CONSTANTS_BY_KEY,
        LIVECHAT_TOKEN: livechat_token(record.chat_setting.site_id, @user.id,
                                        @user.privilege?(:admin_tasks)),
        ASSET_URL: ChatConfig['asset_url'],
        CS_URL: ChatConfig['communication_url'],
        CHAT_ENV: Rails.env,
        FC_HTTP_ONLY: ChatConfig['http_only'] == 1
    }
  end

  private

   def get_current_account
      {
          id: record.id,
          name: record.name ,
          domain: record.full_domain,
          product_id: @portal.product ? @portal.product.id : "",
          chat_enabled: record.chat_setting.enabled,
          widget_id: current_chat_widget.try(:widget_id),
          chat_routing: record.has_feature?(:chat_routing),
          cobrowsing: record.has_feature?(:cobrowsing)
      }
   end

   def get_current_user
     {
       id: @user.id,
       username: @user.name,
       isAdmin: @user.privilege?(:admin_tasks),
       email: @user.email,
       groups: @user.agent_groups.collect{|g| g.group_id},
       language: @user.language,
       time_zone_offset: Time.now.in_time_zone(@user.time_zone).utc_offset,
       falcon_enabled: @user.is_falcon_pref?
     }
   end 

  def current_chat_widget
    return @portal.main_portal ? @record.main_chat_widget : @portal.product.chat_widget
  end



end
