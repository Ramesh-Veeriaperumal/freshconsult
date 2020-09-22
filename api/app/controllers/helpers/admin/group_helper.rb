# frozen_string_literal: true

module Admin::GroupHelper
  include GroupConstants
  def fetch_group_params
    group_params = [] unless api_current_user.privilege?(:admin_tasks)
    group_params = if current_account.agent_statuses_enabled? && !service_group?
                     update? ? UPDATE_PRIVATE_API_FIELDS_WITH_STATUS_TOGGLE_WITHOUT_ASSIGNMENT_CONFIG : PRIVATE_API_FIELDS_WITH_STATUS_TOGGLE_WITHOUT_ASSIGNMENT_CONFIG
                   else
                     update? ? UPDATE_PRIVATE_API_FIELDS_WITHOUT_ASSIGNMENT_CONFIG : PRIVATE_API_FIELDS_WITHOUT_ASSIGNMENT_CONFIG
                   end
    group_params = Account.current.features?(:round_robin) ? group_params | RR_FIELDS : group_params
    Account.current.omni_channel_routing_enabled? ? group_params | OCR_FIELDS : group_params
  end
end
