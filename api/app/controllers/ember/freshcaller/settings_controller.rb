class Ember::Freshcaller::SettingsController < ApiApplicationController
  include Redis::IntegrationsRedis
  include ApplicationHelper

  def desktop_notification
    set_integ_redis_key(key, true, false) if disable_desktop_notification?
    @item = { desktop_notification_disabled: get_integ_redis_key(key) }
  end

  def feature_name
    :freshcaller
  end

  private

    def key
      format(DISABLE_DESKTOP_NOTIFICATIONS, account_id: current_account.id, user_id: api_current_user.id)
    end

    def disable_desktop_notification?
      params[:disable].present? && params[:disable] == 'true'
    end
end
