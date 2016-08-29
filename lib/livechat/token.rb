module Livechat::Token
  def livechat_token(site_id, user_id)
    JWT.encode({:appId => ChatConfig['app_id'], :siteId => site_id, :userId => "#{user_id}" }, ChatConfig['secret_key'])
  end

  def livechat_partial_token(auth_id)
    JWT.encode({:appId => ChatConfig['app_id'], :authId => "#{auth_id}" }, ChatConfig['secret_key'])
  end
end