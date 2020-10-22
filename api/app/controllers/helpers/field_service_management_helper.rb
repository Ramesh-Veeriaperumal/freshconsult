module FieldServiceManagementHelper
  include Admin::AdvancedTicketing::FieldServiceManagement::Constant
  def fetch_fsm_settings
    # Fetching FSM additional settings
    settings = FSM_ADDITIONAL_SETTINGS_DEFAULT_VALUES.dup
    additional_settings = Account.current.account_additional_settings.additional_settings
    fsm_settings = additional_settings[:field_service] || additional_settings[:field_service_management]
    settings.merge!(fsm_settings) if fsm_settings
    # Fetching FSM bitmap settings
    FIELD_SERVICE_PARAMS_SETTINGS_MAPPING.each do |key, setting|
      settings[key.to_sym] = Account.current.safe_send("#{setting}_enabled?")
    end
    settings
  end
end
