module PciConstants
  ISSUER = 'fd'.freeze
  OBJECT_TYPE = 'ticket'.freeze
  EXPIRY_DURATION = 2.minutes.freeze
  MAX_TRY = 2
  PREFIX = '_'.freeze
  ACTION = {
    none: 0,
    read: 1,
    write: 2
  }.freeze
  PORTAL_TYPE = {
    agent_portal: 1,
    support_portal: 2
  }.freeze
  PUBLIC_KEY = File.read('config/cert/jwe_encryption_key.pem')
end
