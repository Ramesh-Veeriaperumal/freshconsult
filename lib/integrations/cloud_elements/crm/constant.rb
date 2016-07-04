module Integrations::CloudElements
  module Crm::Constant
    MAPPING_ELEMENTS = [:salesforce_crm_sync, :dynamics_crm_sync]
    OAUTH_ELEMENTS = ["salesforce_crm_sync"]
    OAUTH_ERROR = "OAuth Token is nil"
  end
end