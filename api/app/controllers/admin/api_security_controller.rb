# frozen_string_literal: true

module Admin
  class ApiSecurityController < ApiApplicationController
    before_filter :validate_settings, only: [:update]
    include HelperConcern
    include Admin::SecurityConstants
    include SecurityConcern

    decorate_views

    def show
      response.api_meta = {}.tap do |meta|
        meta[:current_ip] = request.remote_ip if current_account.whitelisted_ips_enabled?
        if private_api?
          meta[:freshid_migration_in_progress] = @item.freshid_migration_in_progress?
          meta[:freshid_sso_enabled] = @item.freshid_sso_enabled?
        end
      end
    end

    def update
      return unless validate_delegator(@item, cname_params)

      toggle_settings_from_params
      render_errors(@item.errors) unless @item.save
      render_errors(@item.account_configurations.errors) if cname_params[:notification_emails].present? && !@item.account_configuration.save
    end

    private

      def load_object
        @item = current_account
      end

      def validate_params
        @item.security_new_settings_enabled? ? cname_params.permit(*ALLOWED_SECURITY_FIELDS) : cname_params.permit(*(ALLOWED_SECURITY_FIELDS - SECURITY_NEW_SETTINGS))
        security_validation = validation_klass.new(cname_params, @item, string_request_params?)
        render_custom_errors(security_validation, true) unless security_validation.valid?(action_name.to_sym)
      end

      def sanitize_params
        UPDATE_SECURITY_FIELDS.each do |field|
          safe_send("assign_#{field}_settings") if cname_params.key?(field)
        end
      end

      def constants_class
        'Admin::SecurityConstants'
      end

      def toggle_settings_from_params
        setting_params = (AccountSettings::SettingsConfig.keys & cname_params.keys) - SETTINGS_TO_IGNORE
        setting_params.each do |setting|
          cname_params[setting] ? @item.enable_setting(setting.to_sym) : @item.disable_setting(setting.to_sym)
        end
      end

      def validate_settings
        setting_params = (AccountSettings::SettingsConfig.keys & cname_params.keys) - SETTINGS_TO_IGNORE
        setting_params.each do |setting|
          return render_request_error(:require_feature, 403, feature: setting) unless @item.dependencies_enabled?(setting.to_sym)
        end
      end
  end
end
