module FieldServiceManagementHelper
  include Admin::AdvancedTicketing::FieldServiceManagement::Constant
  def fetch_fsm_settings(account_additional_settings)
    settings = FSM_SETTINGS_DEFAULT_VALUES.dup
    additional_settings = account_additional_settings.additional_settings
    fsm_settings = additional_settings[:field_service] || additional_settings[:field_service_management]
    settings.merge!(fsm_settings) if fsm_settings
    FEATURE_MAPPING.each do |key, feature|
      settings[key.to_sym] = Account.current.has_feature?(feature) ? true : false
    end
    settings
  end
end
