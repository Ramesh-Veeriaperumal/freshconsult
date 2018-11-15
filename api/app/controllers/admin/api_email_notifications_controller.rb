class Admin::ApiEmailNotificationsController < ApiApplicationController
  include HelperConcern

  before_filter :check_feature_enabled?

  decorate_views

  def update
    @item.update_attributes(cname_params) ? render(action: :show) : render_custom_errors
  end

  private

    def scoper
      Account.current.email_notifications
    end
 
    def validate_params
      validate_body_params(@item)
    end

    def load_object(items = scoper)
      @item = items.find_by_notification_type(params[:id])
      load_default_template if @item.blank?
      log_and_render_404 unless @item
    end

    def load_default_template
      default_template = ApiEmailNotificationConstants::CUSTOM_NOTIFICATIONS_DEFAULT_TEMPLATE_BY_TYPE[params[:id].to_i]
      @item ||= Account.current.safe_send("#{default_template}") if default_template.present?
    end

    def check_feature_enabled?
      feature_mapping = ApiEmailNotificationConstants::CUSTOM_NOTIFICATIONS_FEATURE_BY_TYPE
      return unless feature_mapping.has_key?(params[:id].to_i)
      render_request_error(:require_feature, 403, feature: feature) unless current_account.safe_send("#{feature_mapping[params[:id].to_i]}_enabled?")
    end

    def constants_class
      'ApiEmailNotificationConstants'.freeze
    end
end