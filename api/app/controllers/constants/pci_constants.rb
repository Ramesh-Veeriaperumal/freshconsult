module PciConstants
  ISSUER = 'fd'.freeze
  OBJECT_TYPE = {
    ticket: 'ticket'
  }.freeze
  EXPIRY_DURATION = 30.seconds.freeze
  MAX_TRY = 2
  PREFIX = '_'.freeze
  ACTION = {
    none: 0,
    read: 1,
    write: 2,
    delete: 3
  }.freeze
  PORTAL_TYPE = {
    agent_portal: 1,
    support_portal: 2
  }.freeze
  PUBLIC_KEY = File.read('config/cert/jwe_encryption_key.pem')
  DATA_URL = SecureFieldConfig['domain'] + 'data'.freeze
  ACCOUNT_INFO_URL = SecureFieldConfig['domain'] + 'account'.freeze
  ACCOUNT_UPDATE = 'update'.freeze
  ACCOUNT_ROLLBACK = 'delete'.freeze
  ALL_FIELDS = ['*'].freeze
end
