class FieldServiceManagementController < ApiApplicationController
  include HelperConcern
  include FieldServiceManagementHelper
  include Admin::AdvancedTicketing::FieldServiceManagement::Constant

  skip_before_filter :load_object
  before_filter :validate_fsm_enabled
  before_filter :check_params, :validate_bitmap_features, :validate_body_params, only: [:update_settings]

  def update_settings
    update_bitmap_features(@bitmap_features) if @bitmap_features.present?
    if @setting_keys.present?
      settings = {}
      @setting_keys.each do |key|
        settings[key.to_sym] = params[cname][key.to_sym]
      end
      scoper.account_additional_settings.save_field_service_management_settings(settings) if @setting_keys.present?
    end
    @fsm_settings = fetch_fsm_settings(current_account.account_additional_settings)
    render 'show_settings'
  end

  def update_bitmap_features(features)
    features.each do |feature|
      params[cname][feature.to_sym] ? scoper.add_feature(FEATURE_MAPPING[feature]) : scoper.revoke_feature(FEATURE_MAPPING[feature])
    end
  end

  def show_settings
    @fsm_settings = fetch_fsm_settings(current_account.account_additional_settings)
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

  def validate_body_params
    @validation_klass = FieldServiceManagementValidation.to_s.freeze
    @constants_klass = Admin::AdvancedTicketing::FieldServiceManagement::Constant.to_s.freeze
    validate_request(nil, params[cname], nil)
  end

  def validate_bitmap_features
    @bitmap_features = FEATURE_MAPPING.keys & params[cname].keys
    @setting_keys = params[cname].keys - FEATURE_MAPPING.keys
    return if @bitmap_features.empty?

    @bitmap_features.each do |feature|
      return render_request_error(:access_denied, 403) unless supported_feature?(feature)
    end
  end

  def supported_feature?(feature)
    toggle_feature = "#{FEATURE_MAPPING[feature]}_toggle".to_sym
    return false if Fdadmin::FeatureMethods::BITMAP_FEATURES.include?(toggle_feature) && !scoper.has_feature?(toggle_feature)
    LAUNCH_PARTY_MAPPING[feature] ? scoper.launched?(LAUNCH_PARTY_MAPPING[feature]) : true
  end
end
