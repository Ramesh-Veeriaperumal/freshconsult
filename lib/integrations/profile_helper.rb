module Integrations::ProfileHelper
  include ChannelIntegrations::Constants

  def get_channel_redis_key(owner, key)
    INTEGRATIONS_REDIS_INFO[:template] % {
      owner: owner,
      key: key,
      account_id: current_account.id
    }
  end

  def get_installed_app(app_name)
    current_account.installed_applications.with_name(app_name).first
  end
end
