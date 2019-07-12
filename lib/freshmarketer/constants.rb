module Freshmarketer
  module Constants
    CREATE_ACCOUNT_URL = '/createsraccount'.freeze
    ASSOCIATE_ACCOUNT_URL = '/associatesraccount'.freeze
    ENABLE_INTEGRATION_URL = '/sr/enableintegration'.freeze
    DISABLE_INTEGRATION_URL = '/sr/disableintegration'.freeze
    GET_CDN_SCRIPT_URL = '/sr/cdnscript'.freeze
    GET_SESSIONS_URL = '/sr/sessions'.freeze
    GET_SESSION_URL = '/sr/session/%<session_id>s'.freeze
    GET_EXPERIMENT_URL = '/sr/expdetails'.freeze
    GET_DOMAINS_URL = '/integrate/admin/domains'.freeze
    REMOVE_ACCOUNT_URL = '/sr/removeaccount'.freeze
    ENABLE_PREDICTIVE_SUPPORT_URL = '/sr/enablepredictivesupport'.freeze
    DISABLE_PREDICTIVE_SUPPORT_URL = '/sr/disablepredictivesupport'.freeze
    CREATE_EXPERIMENT = '/sr/create_experiment'.freeze
    ERROR_CODE_MAPPING = {
      'E400ID' => :invalid_domain_name,
      'E400IE' => :invalid_email_id,
      'E400EA' => :duplicate_email_id,
      'E409IC' => :invalid_credentials,
      'E400II' => :invalid_account_id,
      'E404IR' => :invalid_request,
      'E403IT' => :invalid_access_key,
      'E403IS' => :invalid_scope,
      'E403SR' => :scope_restricted,
      'E409IU' => :invalid_user
    }.freeze
    SESSIONS_LIMIT = 10
    LINK_ACCOUNT_TYPE = %w[create associate associate_using_domain].freeze
  end
end
