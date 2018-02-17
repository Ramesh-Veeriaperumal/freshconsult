module Livechat::Token
  def livechat_token(site_id, user_id, isAdmin)
    isAdmin = User.current.privilege?(:admin_tasks) if isAdmin.nil?
    JWT.encode({:appId => ChatConfig['app_id'], :siteId => site_id,
                :userId => "#{user_id}", :isAdmin => isAdmin }, ChatConfig['secret_key'])
  end

  def livechat_partial_token(auth_id, isAdmin)
    isAdmin = User.current.privilege?(:admin_tasks) if isAdmin.nil?
    JWT.encode({:appId => ChatConfig['app_id'], :authId => "#{auth_id}",
                :isAdmin => isAdmin }, ChatConfig['secret_key'])
  end
end
