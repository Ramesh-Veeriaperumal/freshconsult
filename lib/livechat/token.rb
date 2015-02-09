module Livechat::Token
  def livechat_token(site_id, user_id)
    JWT.encode({:siteId => site_id, :userId => "#{user_id}" }.to_json, ChatConfig['secret_key'])
  end

  def livechat_partial_token(auth_id)
    JWT.encode({:authId => "#{auth_id}"}.to_json , ChatConfig['secret_key'])
  end
end