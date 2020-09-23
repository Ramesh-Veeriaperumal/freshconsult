class Integrations::GoogleHangoutChatController < Admin::AdminController
  before_filter  only: [:oauth]
  before_filter :load_app, only: [:install]

  APP_NAME = Integrations::Constants::APP_NAMES[:google_hangout_chat]

  def oauth
    omniauth_host = "#{AppConfig['integrations_url'][Rails.env]}/auth/google_hangout_chat"
    redirect_url = URI.parse(omniauth_host)
    redirect_url.query = URI.encode_www_form(
      'origin' => "id=#{current_account.id}&portal_id=#{current_portal.id}&falcon_enabled=true"
    )
    redirect_to redirect_url.to_s
  end

  def install
    @installed_app = current_account.installed_applications.build(application: @application)
    @installed_app.configs = {inputs: {}}
    app_configs = get_oauth_params_from_redis
    @installed_app.configs[:inputs].merge!(app_configs)
    @installed_app.save!
    flash[:notice] = t(:'integrations.google_hangout_chat.success').html_safe
    redirect_to "/a/admin#{integrations_applications_path}"
  rescue => e
    Rails.logger.error "Problem in installing Google Hangout Chat new application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
    NewRelic::Agent.notice_error(e, custom_params: {description: "Problem in installing Google Hanout chat new application #{e.message}", account_id: current_account.id})
    flash[:error] = t(:'flash.application.install.error')
    redirect_to "/a/admin#{integrations_applications_path}"
  end

  protected

  def load_app
    @application = Integrations::Application.find_by_name(APP_NAME)
  end

  private

  def get_oauth_params_from_redis(delete = false)
    app_config = JSON.parse(redis_kv_store.get_key)
    raise 'OAuth Token is nil' if app_config['oauth_token'].nil?
    redis_kv_store.remove_key if delete
    app_config
  end

  def redis_kv_store
    key_options = {account_id: current_account.id, provider: APP_NAME.to_s}
    key_value_store_option = {group: :integration}
    Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options), nil, key_value_store_option)
  end

end
