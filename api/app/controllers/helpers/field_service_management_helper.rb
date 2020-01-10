module FieldServiceManagementHelper
  include Admin::AdvancedTicketing::FieldServiceManagement::Constant
  def fetch_fsm_settings(account_additional_settings)
    settings = FSM_SETTINGS_DEFAULT_VALUES.dup
    additional_settings = account_additional_settings.additional_settings[:field_service_management].presence
    settings.merge!(additional_settings) if additional_settings
    settings
  end
end
