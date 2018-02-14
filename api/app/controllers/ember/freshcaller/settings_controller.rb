class Ember::Freshcaller::SettingsController < ApiApplicationController
  include Redis::IntegrationsRedis
  include ApplicationHelper
  include ::Freshcaller::Endpoints
  before_filter :check_freshcaller_account, only: [:redirect_url]
  skip_before_filter :check_falcon, only: [:index]

  def index
    @settings = {
      freshcaller_account_enabled: current_account.freshcaller_account.present?,
      freshcaller_agent_enabled: current_user.agent.freshcaller_agent.present? && current_user.agent.freshcaller_agent.fc_enabled
    }
    if current_account.freshcaller_account.present? && current_account.has_features?(:freshcaller, :freshcaller_widget)
      @settings.merge!(
        freshid_enabled: current_account.freshid_enabled?,
        token: current_account.freshid_enabled? ? nil : sign_payload(email: current_user.email),
        freshcaller_widget_url: freshcaller_widget_url
      )
    end
    response.api_root_key = 'freshcaller_settings'
  end

  def desktop_notification
    set_integ_redis_key(key, true, false) if disable_desktop_notification?
    @item = { desktop_notification_disabled: get_integ_redis_key(key) }
  end

  def feature_name
    :freshcaller
  end

  def redirect_url
    @item = { redirect_url: freshcaller_custom_redirect_url(params[:redirect_path]) }
  end

  private

    def key
      format(DISABLE_DESKTOP_NOTIFICATIONS, account_id: current_account.id, user_id: api_current_user.id)
    end

    def disable_desktop_notification?
      params[:disable].present? && params[:disable] == 'true'
    end

    def check_freshcaller_account
      render_request_error :no_freshcaller_account, Rack::Utils::SYMBOL_TO_STATUS_CODE[:not_found] unless current_account.freshcaller_account.present?
    end
end
