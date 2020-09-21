class Integrations::MicrosoftTeamsController < Admin::AdminController
  class TenantMismatch < StandardError 
  end

  before_filter :load_app, only: [:install, :authorize_agent]
  before_filter :load_installed_app, only: [:authorize_agent]

  MICROSOFT_TEAMS_APP = Integrations::Constants::APP_NAMES[:microsoft_teams]

  def oauth
    redirect_to "#{AppConfig['integrations_url'][Rails.env]}/auth/microsoft_teams?origin=id%3D#{current_account.id}%26portal_id%3D#{current_portal.id}%26user_id%3D#{current_user.id}%26falcon_enabled%3Dtrue"
  end

  def install # change the name to install.
    @installed_app = current_account.installed_applications.build(application: @application)
    @installed_app.configs = { inputs: {} }
    app_configs = get_params_from_redis
    @installed_app.configs[:inputs].merge!(app_configs)
    @installed_app.save!
    flash[:notice] = t(:'flash.application.install.success')
    redirect_to "/a/admin#{integrations_applications_path}"
  rescue => e
    Rails.logger.error "Problem in installing microsoft_teams new application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
    NewRelic::Agent.notice_error(e, custom_params: { description: "Problem in installing microsoft_teams new application #{e.message}", account_id: current_account.id })
    flash[:error] = t(:'flash.application.install.error')
    redirect_to "/a/admin#{integrations_applications_path}"
  end

  def authorize_agent
    begin
      app_config = get_params_from_redis(true)
      raise TenantMismatch if app_config['tenant_id'] != @installed_app.configs_tenant_id # Raise a specific error.
      service_obj(app_config).receive('authorize_agent')
      flash[:notice] = t('integrations.microsoft_teams.token_success').to_s
    rescue TenantMismatch => e
      Rails.logger.error "Tenant id did not match for this user."
      flash[:error] = t('integrations.microsoft_teams.token_failure_duplicate_tenant').to_s
    rescue => e
      Rails.logger.error "Problem in updating the Teams agent oAuth token. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e, custom_params: { description: "Agent authorization failed Teams: #{e.message} ", account_id: current_account.id })
      flash[:error] = t('integrations.microsoft_teams.token_failure').to_s
    end
    redirect_to "/a#{edit_profile_path(current_user)}"
  end

  def render_response
    render json: { text: t('integrations.microsoft_teams.message.action_queued').to_s }
  end

  def service_obj(payload = nil)
    IntegrationServices::Services::MicrosoftTeamsService.new(@installed_app, payload, user_agent: request.user_agent)
  end

  def get_params_from_redis(delete = false)
    redis_kv_val = redis_kv_store
    app_config = JSON.parse(redis_kv_val.get_key)
    redis_kv_val.remove_key if delete
    app_config
  end

  def redis_kv_store
    key_options = { account_id: current_account.id, provider: MICROSOFT_TEAMS_APP.to_s }
    key_value_store_option = { group: :integration }
    Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options), nil, key_value_store_option)
  end

  def load_app
    @application = Integrations::Application.find_by_name(MICROSOFT_TEAMS_APP)
  end

  def load_installed_app
    @installed_app = current_account.installed_applications.find_by_application_id(@application)
    render(json: { text: t('integrations.microsoft_teams.message.not_installed').to_s }) && return if @installed_app.blank?
  end
end
