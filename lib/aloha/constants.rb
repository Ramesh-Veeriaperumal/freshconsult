module Aloha::Constants
  CALLBACK_PARAMS = ['bundle_id', 'bundle_name', 'account_prov_status', 'product_id', 'product_name', 'status_msg', 'account', 'organisation', 'user', 'signup', 'freshdesk_account_id', 'misc', 'anchor'].freeze
  ACCOUNT_PARAMS = ['id', 'domain', 'name', 'description', 'locale', 'timezone', 'alternate_url'].freeze
  ORGANISATION_PARAMS = ['id'].freeze
  USER_PARAMS = ['email'].freeze
  SEEDER_PRODUCTS_ALLOWED = ['freshchat', 'freshcaller'].freeze
  AUTHORIZATION_FAILED = 'Authorization Failed'.freeze
  BUNDLE_DATA_MISMATCH = 'Bundle id/name mismatch'.freeze
  INVALID_SEEDER_PRODUCT = 'Invalid seeder product name'.freeze
  ORG_ID_MISMATCH = 'organisation id mismatch'.freeze
  ORG_ACC_MAP_MISSING_CODE = '101'.freeze
  UPDATE_FRESHCHAT_ACCESS_TOKEN_CODE = '102'.freeze
  ENABLE_FRESHCHAT_AGENT_CODE = '103'.freeze
  BUNDLE_DATA_MISMATCH_CODE = '104'.freeze
  INVALID_SEEDER_PRODUCT_CODE = '105'.freeze
  ENTRY_ALREADY_EXISTS_CODE = '106'.freeze
  ACCOUNT_DETAILS_MISSING_CODE = '107'.freeze
  ACCOUNT_DOMAIN_MISSING_CODE = '108'.freeze
end
