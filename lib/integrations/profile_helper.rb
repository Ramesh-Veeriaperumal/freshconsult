module Integrations::ProfileHelper
  include ChannelIntegrations::Constants
  include ActionView::Helpers::TagHelper

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

  def get_content_tag_for_apps(msg)
    content_tag('div', "#{msg}".html_safe, :class => "alert-message block-message warning full-width warning")
  end
end
