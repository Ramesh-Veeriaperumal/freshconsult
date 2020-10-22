class FieldServiceManagementController < ApiApplicationController
  include HelperConcern
  include FieldServiceManagementHelper
  include Admin::AdvancedTicketing::FieldServiceManagement::Constant

  skip_before_filter :load_object
  before_filter :validate_fsm_enabled
  before_filter :check_params, :validate_body_params, :sanitize_params, :validate_settings, only: [:update_settings]

  def update_settings
    toggle_bitmap_settings(@fsm_bitmap_settings.symbolize_keys) if @fsm_bitmap_settings.present?
    scoper.account_additional_settings.save_field_service_management_settings(@fsm_additional_settings.symbolize_keys) if @fsm_additional_settings.present?
    @fsm_settings = fetch_fsm_settings
    render 'show_settings'
  end

  def toggle_bitmap_settings(settings)
    settings.each do |setting, value|
      value ? scoper.enable_setting(setting) : scoper.disable_setting(setting)
    end
  end

  def show_settings
    @fsm_settings = fetch_fsm_settings
  end

  private

  def validate_fsm_enabled
    if scoper.field_service_management_toggle_enabled?
      render_request_error(:require_fsm_feature, 403) unless scoper.field_service_management_enabled?
    else
      render_request_error(:require_feature, 403, feature: 'field_service_management'.titleize)
    end
  end

  def scoper
    current_account
  end

  def sanitize_params
    FIELD_SERVICE_PARAMS_SETTINGS_MAPPING.each do |param_key, setting_key|
      params[cname][setting_key] = params[cname].delete(param_key) if params[cname].key?(param_key)
    end
  end

  def validate_body_params
    @validation_klass = FieldServiceManagementValidation.to_s.freeze
    @constants_klass = Admin::AdvancedTicketing::FieldServiceManagement::Constant.to_s.freeze
    validate_request(nil, params[cname], nil)
  end

  def validate_settings
    @fsm_bitmap_settings = params[cname].slice(*(AccountSettings::SettingsConfig.keys & params[cname].keys))
    @fsm_additional_settings = params[cname].slice(*(params[cname].keys - @fsm_bitmap_settings.keys))
    return if @fsm_bitmap_settings.empty?

    @fsm_bitmap_settings.each_key do |setting|
      return render_request_error(:access_denied, 403) unless supported_setting?(setting.to_sym)
      return render_request_error(:require_feature, 403) unless scoper.dependencies_enabled?(setting.to_sym)
    end
  end

  def supported_setting?(setting)
    SETTINGS_LAUNCH_PARTY_MAPPING[setting] ? scoper.launched?(SETTINGS_LAUNCH_PARTY_MAPPING[setting]) : true
  end
end
